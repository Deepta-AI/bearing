#!/usr/bin/env python3
"""trace_check: walk the chain REQ, US, AC, TC, test, ticket, commit, ADR and
event with exact ids, and count every gap class, from the files and the git
log, never from the matrix the model wrote.

Sources (each read or missing; a missing one is a gap row of its own):
  - REQ ids: the PRD's statement rows (`| REQ-nnn |`), rows marked
    `withdrawn:` skipped.
  - EP, US and AC ids: backlog.md headings and bodies; a story heading or
    Status line marked `withdrawn:` is skipped. `Covers:` lines link REQ to
    US, a `Ticket:` line links US to a ticket, an `Events:` line names the
    story's events in backticks.
  - Coverage claims: docs/product/coverage.md rows (`| REQ-nnn | US ids |`)
    are checked against the backlog's Covers lines, and its "every
    acceptance criterion has a test case" and "every test case is
    automated" sentences against the gaps found.
  - TC ids: the rows of docs/testing/test-cases.md (`| TC-nnnn |`), rows
    marked `retired` skipped; the AC ids in a row link AC to TC.
  - Tests: files named *_test.go, *.test.ts(x), *.spec.ts(x), test_*.py,
    *_test.py, *Test.kt, *Tests.swift under --root, split into test
    functions (the comment and decorator lines directly above a function
    belong to it). A TC id in a function links TC to test; a US id is the
    weaker link. A function that skips (t.Skip, pytest skip marks, it.skip,
    xit, @Disabled, XCTSkip) links nothing: its ids are reported as skipped.
    So does a test the default run never executes: a Go file behind a
    `//go:build` tag that no Makefile or CI file passes with -tags, or a
    pytest function carrying a marker the configured addopts deselect
    (`-m "not <marker>"`).
  - Commits: `git log <merge base>..HEAD` with --base, else `git log HEAD`
    (every commit, the root included), run by this script; or a log given with
    --log FILE|- in the format
      git log --format='@@commit %h%n%s%n%b@@files' --name-only <base>..HEAD
  - ADR ids from docs/adr/NNNN-*.md; US or ticket ids mentioned in
    docs/adr, docs/design and docs/runbooks link a story to its docs.
  - Events: backticked names in the first column of EVENT_SHEET.md.

Scope: with --base, the stories in scope are those named in the range's
commits, added to the backlog since the merge base, or named in a test file
changed since it. Gaps of other stories, REQ without story and missing
sources print as "outside scope:" and do not decide the verdict. Without
--base (full history) every active story is in scope.

Gap classes: REQ without story, story without AC, AC without TC, TC without
test, TC test skipped, story without test (only when there is no test-case
document), unknown id (a US or TC id in a test or commit that the backlog or
the test cases do not hold), coverage claim contradicted, story without
ticket, ticket without commits (both n/a with --tracker none), commit without
id (no ticket, story or epic id), boundary change without ADR (a commit
touching migrations/, an auth path or a dependency manifest whose ids no ADR
mentions, counted only when an ADR requires a record for that kind of
change, otherwise a "review:" line), event not in sheet, missing source.
The root commit of a full audit is never a boundary change, and its missing
id is a "review:" line, not a gap: it predates the work.

Usage: trace_check.py [--base REF] [--log FILE|-] [--prd P] [--backlog B]
       [--coverage C] [--cases C] [--root R] [--adr D] [--docs D ...]
       [--events E] [--prefix KEY] [--tracker NAME]
Prints one "problem:" line per gap in scope, "outside scope:", "review:" and
"not run by default:" lines, a "tests:" line per story in scope naming its test functions, the
Scope, Ids, Links, Gaps and Unknown tickets lines, the counts line and the
verdict; exits 1 on any gap in scope, or when no id of any class and no
commit was read.
"""

import argparse
import os
import re
import subprocess
import sys

REQ = re.compile(r"\bREQ-\d{3}\b")
US = re.compile(r"\bUS-\d{2}-\d{3}\b")
AC = re.compile(r"\bAC-US-\d{2}-\d{3}-\d+\b")
TC = re.compile(r"\bTC-\d{4}\b")
KIT_PREFIXES = {"REQ", "US", "AC", "TC", "ADR", "EP", "T", "S", "B", "E", "F"}
TEST_NAME = re.compile(
    r"(_test\.go|\.test\.tsx?|\.spec\.tsx?|\.test\.jsx?|\.spec\.jsx?|_test\.py|Test\.kt|Tests\.swift)$|^test_.*\.py$"
)
SKIP_DIRS = {
    ".git",
    "node_modules",
    "vendor",
    "dist",
    "build",
    ".venv",
    "venv",
    "__pycache__",
    ".bearing",
}
BOUNDARY = re.compile(
    r"(^|/)migrations?/|auth|(^|/)(go\.mod|package\.json|pyproject\.toml|requirements[^/]*\.txt|"
    r"build\.gradle(\.kts)?|Package\.swift|Cargo\.toml|Gemfile|pubspec\.yaml)$"
)
# A boundary change is a gap only when an ADR asks for a record of that kind.
BOUNDARY_RULE = {
    "migration": re.compile(
        r"(schema|migration|table)[^.]{0,80}\b(need|needs|require|requires|must)\b",
        re.I,
    ),
    "auth": re.compile(r"auth[^.]{0,80}\b(need|needs|require|requires|must)\b", re.I),
    "dependency": re.compile(
        r"(dependenc|librar|package)[^.]{0,80}\b(need|needs|require|requires|must)\b",
        re.I,
    ),
}
DECL = re.compile(
    r"^\s*(?:func\s+(?:\([^)]*\)\s*)?(Test\w*|test\w*)\s*\("  # Go, Swift
    r"|(?:async\s+)?def\s+(test\w*)\s*\("  # Python
    r"|x?(?:it|test)(?:\.(?:skip|only|todo))?\s*\(\s*['\"`]([^'\"`]*)"  # JS, TS
    r"|(?:(?:public|private|internal)\s+)?fun\s+`?([^`(]+)`?\s*\()"  # Kotlin
)
PLATFORM_TAGS = {
    "linux", "darwin", "windows", "freebsd", "openbsd", "netbsd", "dragonfly",
    "solaris", "illumos", "aix", "android", "ios", "js", "wasip1", "plan9",
    "hurd", "zos", "unix", "amd64", "arm64", "386", "arm", "wasm", "ppc64",
    "ppc64le", "mips", "mipsle", "mips64", "mips64le", "riscv64", "s390x",
    "loong64", "cgo", "gc", "gccgo",
}
RUN_CONFIG = (
    "Makefile", "GNUmakefile", "makefile", ".gitlab-ci.yml", "Taskfile.yml",
    "justfile", "pytest.ini", "pyproject.toml", "setup.cfg", "tox.ini",
)
SKIP = re.compile(
    r"\bt\.Skip(?:f|Now)?\(|\bpytest\.skip\(|@pytest\.mark\.(?:skip|skipif|xfail)\b"
    r"|@unittest\.skip|\b(?:it|test|describe)\.(?:skip|todo)\(|^\s*x(?:it|test|describe)\("
    r"|@Disabled\b|@Ignore\b|\bXCTSkip|pytestmark\s*=.*skip",
    re.M,
)


def read(path):
    return (
        open(path, encoding="utf-8", errors="replace").read()
        if path and os.path.isfile(path)
        else None
    )


def git(root, *args):
    try:
        r = subprocess.run(
            ["git", *args], cwd=root, capture_output=True, text=True, check=False
        )
    except OSError:
        return None
    return r.stdout if r.returncode == 0 else None


def req_ids(text):
    ids = []
    for line in (text or "").split("\n"):
        m = re.match(r"^\|\s*(REQ-\d{3})\s*\|", line)
        if m and "withdrawn:" not in line and m.group(1) not in ids:
            ids.append(m.group(1))
    return ids


def parse_backlog(text):
    """(active stories, withdrawn ids); id -> {covers, ac, ticket_line, events}."""
    stories, cur, withdrawn = {}, None, set()
    for line in (text or "").split("\n"):
        h = re.match(r"^#{2,4}\s+(US-\d{2}-\d{3})\b(.*)$", line)
        if h:
            cur = h.group(1)
            stories[cur] = {
                "covers": set(),
                "ac": [],
                "ticket_line": "",
                "events": set(),
            }
            if "withdrawn:" in h.group(2):
                withdrawn.add(cur)
            continue
        if re.match(r"^#{1,4}\s", line):
            if re.match(r"^#{2,4}\s+EP-\d{2}\b", line):
                cur = None
            continue
        if cur is None:
            continue
        st = stories[cur]
        if line.lstrip().startswith(("Status", "withdrawn:")) and "withdrawn:" in line:
            withdrawn.add(cur)
        for a in AC.findall(line):
            if a.startswith("AC-" + cur + "-") and a not in st["ac"]:
                st["ac"].append(a)
        if "Covers:" in line:
            st["covers"] |= set(REQ.findall(line.split("Covers:", 1)[1]))
        if re.match(r"^\s*[-*]?\s*Ticket:", line):
            st["ticket_line"] += " " + line.split("Ticket:", 1)[1]
        if re.match(r"^\s*[-*]?\s*Events?:", line):
            st["events"] |= set(re.findall(r"`([a-z][a-z0-9_.]*)`", line))
    active = {k: v for k, v in stories.items() if k not in withdrawn}
    return active, withdrawn


def parse_cases(text):
    """(TC id -> set of AC ids, retired TC ids)."""
    cases, retired = {}, set()
    for line in (text or "").split("\n"):
        m = re.match(r"^\|\s*(TC-\d{4})\s*\|", line)
        if not m:
            continue
        cells = [c.strip().lower() for c in line.strip().strip("|").split("|")]
        if "retired" in cells:
            retired.add(m.group(1))
            continue
        cases.setdefault(m.group(1), set()).update(AC.findall(line))
    return cases, retired


def parse_log(text):
    """[{sha, subject, body, files}] from the @@commit/@@files format."""
    commits = []
    for block in (text or "").split("@@commit ")[1:]:
        head, _, files = block.partition("@@files")
        lines = head.split("\n")
        commits.append(
            {
                "sha": lines[0].strip(),
                "subject": lines[1] if len(lines) > 1 else "",
                "body": "\n".join(lines[2:]),
                "files": [f.strip() for f in files.split("\n") if f.strip()],
            }
        )
    return commits


def walk_tests(root):
    found = []
    for d, dirs, files in os.walk(root):
        dirs[:] = [x for x in dirs if x not in SKIP_DIRS]
        for f in files:
            if TEST_NAME.search(f):
                found.append(os.path.join(d, f))
    return sorted(found)


def test_blocks(text):
    """[(name, text, skipped)]: one block per test function, the comment and
    decorator lines directly above a declaration attached to it; the text
    before the first declaration is a block named None, and a skip there
    (a module-level pytestmark) skips the whole file."""
    lines = text.split("\n")
    bounds = [(0, None)]
    for i, line in enumerate(lines):
        m = DECL.match(line)
        if not m:
            continue
        name = next(g for g in m.groups() if g is not None).strip()
        j = i
        while j > bounds[-1][0] + 1 and re.match(r"^\s*(//|#|@|/\*|\*)", lines[j - 1]):
            j -= 1
        bounds.append((j, name))
    blocks = []
    for idx, (j, name) in enumerate(bounds):
        end = bounds[idx + 1][0] if idx + 1 < len(bounds) else len(lines)
        blocks.append((name, "\n".join(lines[j:end])))
    head_skip = bool(SKIP.search(blocks[0][1]))
    return [(n, t, head_skip or bool(SKIP.search(t))) for n, t in blocks if t.strip()]


def run_config(root):
    """The text of the files that say how the tests run: Makefile, CI, pytest
    configuration."""
    parts = [read(os.path.join(root, f)) or "" for f in RUN_CONFIG]
    wf = os.path.join(root, ".github", "workflows")
    if os.path.isdir(wf):
        parts += [read(os.path.join(wf, f)) or "" for f in sorted(os.listdir(wf))]
    return "\n".join(parts)


def not_run_reason(path, text, config):
    """Why the default test run never executes this file, or None."""
    if path.endswith(".go"):
        for line in text.split("\n"):
            if line.startswith("package "):
                break
            m = re.match(r"^//go:build\s+(.+)$", line)
            if not m:
                continue
            needed = [
                t
                for t in re.findall(r"(?<![!\w.])([A-Za-z_][\w.]*)", m.group(1))
                if t not in PLATFORM_TAGS and not re.match(r"^go1\.\d+$", t)
            ]
            passed = set()
            for tags in re.findall(r"-tags[= ]+['\"]?([\w,. ]+)", config):
                passed |= set(re.split(r"[ ,]+", tags.strip()))
            unset = [t for t in needed if t not in passed]
            if unset:
                return f"build tag {', '.join(unset)} not set by any Makefile or CI -tags"
    return None


def deselected_markers(config):
    """pytest markers the configured run deselects with -m "not x"."""
    out = set()
    for expr in re.findall(r"-m\s+['\"]([^'\"]+)['\"]", config):
        out |= set(re.findall(r"\bnot\s+(\w+)", expr))
    return out


def docs_text(paths):
    out = {}
    for p in paths:
        if os.path.isdir(p):
            for d, dirs, files in os.walk(p):
                for f in files:
                    if f.endswith(".md"):
                        out[os.path.join(d, f)] = read(os.path.join(d, f))
        elif os.path.isfile(p):
            out[p] = read(p)
    return out


def boundary_kind(path):
    if re.search(r"(^|/)migrations?/", path):
        return "migration"
    return "auth" if "auth" in path else "dependency"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--prd", default="docs/product/PRD.md")
    ap.add_argument("--backlog", default="docs/product/backlog.md")
    ap.add_argument("--coverage", default="docs/product/coverage.md")
    ap.add_argument("--cases", default="docs/testing/test-cases.md")
    ap.add_argument("--root", default=".")
    ap.add_argument("--base", default=None)
    ap.add_argument("--log", default=None)
    ap.add_argument("--adr", default="docs/adr")
    ap.add_argument("--docs", nargs="*", default=["docs/design", "docs/runbooks"])
    ap.add_argument("--events", default="docs/analytics/EVENT_SHEET.md")
    ap.add_argument("--prefix", default="")
    ap.add_argument("--tracker", default="")
    a = ap.parse_args()

    sources_read, missing = 0, []
    prd, backlog, cases_md, sheet, coverage = (
        read(a.prd),
        read(a.backlog),
        read(a.cases),
        read(a.events),
        read(a.coverage),
    )
    for path, text in ((a.prd, prd), (a.backlog, backlog), (a.cases, cases_md)):
        if text is None:
            missing.append(path)
        else:
            sources_read += 1
    if coverage is not None:
        sources_read += 1

    # The range: a given log, or git log from the merge base with --base, or
    # from the root commit.
    log_text, range_desc, merge_base, root_sha = None, "log not given", None, ""
    if a.log == "-":
        log_text, range_desc = sys.stdin.read(), "log from stdin"
    elif a.log:
        log_text, range_desc = read(a.log), f"log {a.log}"
        if log_text is None:
            missing.append(a.log)
    elif git(a.root, "rev-parse", "--git-dir") is not None:
        start, rng = "", "HEAD"
        if a.base:
            merge_base = (git(a.root, "merge-base", a.base, "HEAD") or "").strip()
            if not merge_base:
                print(f"trace_check: base {a.base} not found", file=sys.stderr)
                return 1
            start, rng = merge_base, f"{merge_base}..HEAD"
        else:
            roots = (git(a.root, "rev-list", "--max-parents=0", "HEAD") or "").split()
            start = root_sha = roots[-1] if roots else ""
        if start:
            log_text = git(
                a.root,
                "log",
                "--format=@@commit %h%n%s%n%b@@files",
                "--name-only",
                rng,
            )
            range_desc = (
                f"{a.base} (merge base {start[:7]})..HEAD"
                if a.base
                else f"every commit from the root {start[:7]} to HEAD"
            )
    if log_text is not None:
        sources_read += 1

    reqs = req_ids(prd)
    stories, withdrawn_us = parse_backlog(backlog)
    acs = [ac for st in stories.values() for ac in st["ac"]]
    cases, retired_tc = parse_cases(cases_md)
    commits = parse_log(log_text)

    # Tests, per function.
    test_files = walk_tests(a.root)
    config = run_config(a.root)
    deselected = deselected_markers(config)
    tc_run, tc_skipped, us_run, us_skipped = {}, {}, {}, {}
    unknown_ids, tests_linked, not_run = [], 0, []
    for f in test_files:
        rel = os.path.relpath(f, a.root)
        linked = False
        body = read(f) or ""
        why_file = not_run_reason(rel, body, config)
        if why_file:
            not_run.append(f"{rel}: {why_file}")
        for name, text, skipped in test_blocks(body):
            label = f"{rel} {name}" if name else rel
            marks = set(re.findall(r"@pytest\.mark\.(\w+)", text)) & deselected
            why = why_file or (
                f"marker {', '.join(sorted(marks))} deselected by the configured run"
                if marks and rel.endswith(".py")
                else None
            )
            if why:
                skipped, label = True, f"{label}, {why}"
            for t in sorted(set(TC.findall(text))):
                (tc_skipped if skipped else tc_run).setdefault(t, []).append(label)
                linked = True
                if cases_md is not None and t not in cases and t not in retired_tc:
                    unknown_ids.append(f"{t} in {label} (not in {a.cases})")
            for u in sorted(set(US.findall(text))):
                (us_skipped if skipped else us_run).setdefault(u, []).append(label)
                if backlog is not None and u not in stories:
                    why = "withdrawn" if u in withdrawn_us else f"not in {a.backlog}"
                    unknown_ids.append(f"{u} in {label} ({why})")
        tests_linked += 1 if linked else 0

    adr_files = {}
    if os.path.isdir(a.adr):
        sources_read += 1
        for f in sorted(os.listdir(a.adr)):
            m = re.match(r"^(\d{4})-.*\.md$", f)
            if m:
                adr_files["ADR-" + m.group(1)] = read(os.path.join(a.adr, f)) or ""
    other_docs = docs_text(a.docs)
    if sheet is not None:
        sources_read += 1
    sheet_events = set()
    for line in (sheet or "").split("\n"):
        m = re.match(r"^\|\s*`([a-z][a-z0-9_.]*)`\s*\|", line)
        if m:
            sheet_events.add(m.group(1))

    # Tickets.
    tracker_none = a.tracker.lower() == "none"
    prefix, inferred = a.prefix, False
    if not prefix and not tracker_none:
        seen = {}
        for c in commits:
            for m in re.finditer(r"\b([A-Z][A-Z0-9]*)(?:-\d+)+\b", c["subject"]):
                if m.group(1) not in KIT_PREFIXES:
                    seen[m.group(1)] = seen.get(m.group(1), 0) + 1
        if seen:
            prefix, inferred = max(seen, key=seen.get), True
    ticket_re = (
        re.compile(r"\b" + re.escape(prefix) + r"(?:-\d+)+\b") if prefix else None
    )
    story_tickets = {}
    for sid, st in stories.items():
        story_tickets[sid] = (
            set(ticket_re.findall(st["ticket_line"])) if ticket_re else set()
        )
    for c in commits:
        text = c["subject"] + "\n" + c["body"]
        c["tickets"] = set(ticket_re.findall(text)) if ticket_re else set()
        c["subject_tickets"] = (
            set(ticket_re.findall(c["subject"])) if ticket_re else set()
        )
        c["us"] = set(US.findall(text))
        for sid in c["us"] & set(stories):
            story_tickets[sid] |= c["tickets"]
    known_tickets = set().union(*story_tickets.values()) if story_tickets else set()
    commit_tickets = set().union(*(c["tickets"] for c in commits)) if commits else set()
    unknown_tickets = sorted(commit_tickets - known_tickets)

    # Scope: every active story, or the ones the branch touched.
    if merge_base:
        scope = set()
        for c in commits:
            scope |= c["us"]
        diff = (
            git(a.root, "diff", "--unified=0", f"{merge_base}..HEAD", "--", a.backlog)
            or ""
        )
        for line in diff.split("\n"):
            m = re.match(r"^\+#{2,4}\s+(US-\d{2}-\d{3})\b", line)
            if m:
                scope.add(m.group(1))
        changed = (
            git(a.root, "diff", "--name-only", f"{merge_base}..HEAD") or ""
        ).split()
        for f in changed:
            if TEST_NAME.search(os.path.basename(f)):
                scope |= set(US.findall(read(os.path.join(a.root, f)) or ""))
        scope &= set(stories)
    else:
        scope = set(stories)
    in_scope_ac = [ac for s in sorted(scope) for ac in stories[s]["ac"]]

    classes = (
        "REQ without story",
        "story without AC",
        "AC without TC",
        "TC without test",
        "TC test skipped",
        "story without test",
        "unknown id",
        "coverage claim contradicted",
        "story without ticket",
        "ticket without commits",
        "commit without id",
        "boundary change without ADR",
        "event not in sheet",
        "missing source",
    )
    fix = {
        "REQ without story": "backlog",
        "story without AC": "backlog",
        "AC without TC": "test-cases",
        "TC without test": "write the test, name it with the TC id",
        "TC test skipped": "find why it fails and fix the code or the test; a skipped test verifies nothing",
        "story without test": "write a test per acceptance criterion, name it with the story id",
        "unknown id": "correct the id to the story or case the test really covers",
        "coverage claim contradicted": "correct the coverage document",
        "story without ticket": "create the ticket, add Ticket: to the story",
        "ticket without commits": "start-task, commit with [<KEY>]",
        "commit without id": "reword before merge, or name the id in the MR",
        "boundary change without ADR": "adr",
        "event not in sheet": "analytics-events",
        "missing source": "the skill that writes it",
    }
    gaps = {k: [] for k in classes}
    outside = {k: [] for k in classes}

    def put(cls, item, story=None):
        (gaps if story is None or story in scope else outside)[cls].append(item)

    covered = (
        set().union(*(st["covers"] for st in stories.values())) if stories else set()
    )
    l_req_us = sum(1 for r in reqs if r in covered)
    for r in reqs:
        if r not in covered:
            (outside if merge_base else gaps)["REQ without story"].append(r)
    for s, st in stories.items():
        if not st["ac"]:
            put("story without AC", s, s)
    tc_acs = set().union(*cases.values()) if cases else set()
    story_of_ac = {ac: s for s, st in stories.items() for ac in st["ac"]}
    story_of_tc = {
        t: next((story_of_ac[x] for x in sorted(v) if x in story_of_ac), None)
        for t, v in cases.items()
    }
    if cases_md is not None:
        for ac in acs:
            if ac not in tc_acs:
                put("AC without TC", ac, story_of_ac[ac])
        for t in cases:
            if t in tc_run:
                continue
            if t in tc_skipped:
                put(
                    "TC test skipped",
                    f"{t} ({', '.join(tc_skipped[t])})",
                    story_of_tc[t],
                )
            else:
                put("TC without test", t, story_of_tc[t])
    else:
        for s in stories:
            if s in us_run:
                continue
            only = (
                f" (only skipped: {', '.join(us_skipped[s])})"
                if s in us_skipped
                else ""
            )
            put("story without test", s + only, s)
    gaps["unknown id"].extend(unknown_ids)
    for c in commits:
        for u in sorted(c["us"] - set(stories)):
            why = "withdrawn" if u in withdrawn_us else f"not in {a.backlog}"
            gaps["unknown id"].append(f"{u} in commit {c['sha']} ({why})")
    l_tc_test = sum(1 for t in cases if t in tc_run)

    # Coverage claims, checked against the backlog and the gaps found.
    if coverage is not None:
        for line in coverage.split("\n"):
            m = re.match(r"^\|\s*(REQ-\d{3})\s*\|([^|]*)\|", line)
            if not m or re.search(r"not covered|missing|\bgap\b|\bnone\b", line, re.I):
                continue
            r, listed = m.group(1), US.findall(m.group(2))
            if not listed and r not in covered:
                gaps["coverage claim contradicted"].append(
                    f"{a.coverage} marks {r} covered; no story's Covers: names it"
                )
            for s in listed:
                if s in stories and r not in stories[s]["covers"]:
                    gaps["coverage claim contradicted"].append(
                        f"{a.coverage} lists {s} for {r}; that story's Covers: does not name {r}"
                    )
        claims = re.sub(r"\s+", " ", coverage.lower())
        n_ac = len(gaps["AC without TC"]) + len(outside["AC without TC"])
        if n_ac and re.search(
            r"every (acceptance criteri\w*|ac)\b[^.]{0,40}\btest case", claims
        ):
            gaps["coverage claim contradicted"].append(
                f"{a.coverage} says every acceptance criterion has a test case; AC without one: {n_ac}"
            )
        n_auto = sum(
            len(d[k])
            for d in (gaps, outside)
            for k in ("TC without test", "TC test skipped")
        )
        if n_auto and re.search(r"every test case is automated", claims):
            gaps["coverage claim contradicted"].append(
                f"{a.coverage} says every test case is automated; TC with no running test: {n_auto}"
            )

    na = tracker_none or not prefix
    if not na:
        for s in stories:
            if not story_tickets[s]:
                put("story without ticket", s, s)
        subj = (
            set().union(*(c["subject_tickets"] for c in commits)) if commits else set()
        )
        for t in sorted(known_tickets - subj):
            owner = next((s for s in stories if t in story_tickets[s]), None)
            put("ticket without commits", t, owner)
    l_us_ticket = sum(1 for s in stories if story_tickets[s])
    l_ticket_commit = sum(
        1 for t in known_tickets if any(t in c["subject_tickets"] for c in commits)
    )
    reviews = []
    for c in commits:
        named = c["tickets"] or c["us"] or re.search(r"\bEP-\d{2}\b", c["subject"] + c["body"])
        if c["subject"].startswith("Merge ") or named:
            continue
        if root_sha and root_sha.startswith(c["sha"]):
            reviews.append(f"root commit {c['sha']} {c['subject']} names no id; it predates the work")
        else:
            gaps["commit without id"].append(f"{c['sha']} {c['subject']}")
    adr_text = "\n".join(adr_files.values())
    for c in commits:
        touched = [f for f in c["files"] if BOUNDARY.search(f)]
        ids = c["tickets"] | c["us"]
        if root_sha and root_sha.startswith(c["sha"]):
            continue  # creating the repository is not a boundary change
        if not touched or (ids and any(i in adr_text for i in ids)):
            continue
        kind = boundary_kind(touched[0])
        rules = [k for k, v in adr_files.items() if BOUNDARY_RULE[kind].search(v)]
        item = f"{c['sha']} ({touched[0]})"
        if rules:
            gaps["boundary change without ADR"].append(
                f"{item}, {', '.join(rules)} asks for a record of {kind} changes"
            )
        else:
            reviews.append(
                f"boundary change {item}: no ADR mentions it and none asks for one; judge whether it is a decision"
            )
    all_docs = adr_text + "\n" + "\n".join(t or "" for t in other_docs.values())
    l_us_docs = sum(
        1
        for s in stories
        if s in all_docs or any(t in all_docs for t in story_tickets[s])
    )
    l_us_event = 0
    for s, st in stories.items():
        if st["events"] and st["events"] <= sheet_events:
            l_us_event += 1
        for e in sorted(st["events"] - sheet_events):
            put("event not in sheet", f"{e} ({s})", s)
    miss = outside if merge_base else gaps
    if prd is None and stories:
        miss["missing source"].append(
            f"missing {a.prd}: {len(stories)} stories could not be linked upward (prd)"
        )
    if backlog is None and reqs:
        miss["missing source"].append(
            f"missing {a.backlog}: {len(reqs)} REQ could not be linked downward (backlog)"
        )
    if cases_md is None and acs:
        miss["missing source"].append(
            f"missing {a.cases}: {len(acs)} AC could not be linked to a case (test-cases); "
            "stories judged by their ids in tests"
        )

    n_ids = (
        len(reqs)
        + len(stories)
        + len(acs)
        + len(cases)
        + len(known_tickets | commit_tickets)
    )
    if n_ids == 0 and not commits:
        print(
            f"traceability: 0 ids and 0 commits read ({a.prd}, {a.backlog}, {a.cases}, {range_desc}), nothing checked",
            file=sys.stderr,
        )
        return 1

    for cls in classes:
        for i in gaps[cls]:
            print(f"problem: {cls}: {i} (fix: {fix[cls]})")
    for cls in classes:
        for i in outside[cls]:
            print(f"outside scope: {cls}: {i}")
    for r in reviews:
        print(f"review: {r}")
    for n in not_run:
        print(f"not run by default: {n}")
    for s in sorted(scope):
        via_tc = sorted(
            {lab for t in cases if story_of_tc.get(t) == s for lab in tc_run.get(t, [])}
        )
        via_us = sorted(set(us_run.get(s, [])) - set(via_tc))
        parts = []
        if via_tc:
            parts.append(", ".join(via_tc) + " (by TC id)")
        if via_us:
            parts.append(", ".join(via_us) + " (by story id)")
        print(f"tests: {s} ({len(stories[s]['ac'])} AC): {'; '.join(parts) or 'none'}")
    n_ticket = (
        "n/a (tracker: none)" if tracker_none else ("n/a (no prefix)" if na else None)
    )
    k = {cls: len(v) for cls, v in gaps.items()}
    t5 = n_ticket or k["story without ticket"]
    t6 = n_ticket or k["ticket without commits"]
    print(
        f"Scope: {'branch' if merge_base else 'full history'}, {range_desc}, "
        f"{len(scope)} of {len(stories)} stories, {len(in_scope_ac)} AC"
        + (f" ({', '.join(sorted(scope))})" if merge_base else "")
    )
    print(
        f"Ids: REQ {len(reqs)}, US {len(stories)}, AC {len(acs)}, TC {len(cases)}, tests {tests_linked}, "
        f"tickets {len(known_tickets | commit_tickets)}, ADR {len(adr_files)}, events {len(sheet_events)}"
    )
    print(
        f"Links: REQ>US {l_req_us}, US>AC {sum(1 for st in stories.values() if st['ac'])}, "
        f"AC>TC {sum(1 for x in acs if x in tc_acs)}, TC>test {l_tc_test}, US>ticket {l_us_ticket}, "
        f"ticket>commit {l_ticket_commit}, US>docs {l_us_docs}, US>event {l_us_event} "
        f"(US ids in tests, weaker: {len(set(us_run) & set(stories))})"
    )
    print(
        f"Gaps: REQ without story {k['REQ without story']}, story without AC {k['story without AC']}, "
        f"AC without TC {k['AC without TC']}, TC without test {k['TC without test']}, "
        f"TC test skipped {k['TC test skipped']}, story without test {k['story without test']}, "
        f"unknown id {k['unknown id']}, coverage claim contradicted {k['coverage claim contradicted']}, "
        f"story without ticket {t5}, ticket without commits {t6}, commit without id {k['commit without id']}, "
        f"boundary change without ADR {k['boundary change without ADR']}, "
        f"event not in sheet {k['event not in sheet']}, missing source {k['missing source']}"
    )
    print(
        f"Unknown tickets: {len(unknown_tickets)}{' (' + ', '.join(unknown_tickets) + ')' if unknown_tickets else ''}"
    )
    total = sum(k.values())
    n_cls = sum(1 for v in k.values() if v)
    n_out = sum(len(v) for v in outside.values())
    pfx = f"{prefix}{' inferred' if inferred else ''}" if prefix else "none"
    print(
        f"traceability: {sources_read} sources read, {len(missing)} missing, {len(commits)} commits, "
        f"{len(test_files)} test files, prefix {pfx}, {total} gaps in {n_cls} classes, "
        f"{n_out} outside scope, {len(reviews)} to review"
    )
    print(
        f"Verdict: {'traced' if total == 0 else f'not traced ({total} gaps in {n_cls} classes)'}"
    )
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
