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
  - TC ids: the rows of docs/testing/test-cases.md (`| TC-nnnn |`), rows
    marked `retired` skipped; the AC ids in a row link AC to TC.
  - Tests: files named *_test.go, *.test.ts(x), *.spec.ts(x), test_*.py,
    *_test.py, *Test.kt, *Tests.swift under --root; a TC id in a file
    links TC to test, a US id is the weaker link, counted apart.
  - Commits: the output of
      git log --format='@@commit %h%n%s%n%b@@files' --name-only <base>..HEAD
    given with --log <file> (or - for stdin). Ticket ids in a subject link
    tickets to commits; a commit naming a US id and a ticket id links them.
  - ADR ids from docs/adr/NNNN-*.md; US or ticket ids mentioned in
    docs/adr, docs/design and docs/runbooks link a story to its docs.
  - Events: backticked names in the first column of EVENT_SHEET.md.

Gap classes: REQ without story, story without AC, AC without TC, TC without
test, story without ticket, ticket without commits (both n/a with
--tracker none), boundary change without ADR (a commit touching
migrations/, an auth path or a dependency manifest whose ids no ADR
mentions; new routes are not detected), event not in sheet, missing source.

Usage: trace_check.py [--prd P] [--backlog B] [--cases C] [--root R]
       [--log FILE|-] [--adr D] [--docs D ...] [--events E]
       [--prefix KEY] [--tracker NAME]
Prints one "problem:" line per gap, the Ids, Links, Gaps and Unknown
tickets lines, the counts line and the verdict; exits 1 on any gap, or when
no id of any class and no commit was read.
"""

import argparse
import os
import re
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


def read(path):
    return (
        open(path, encoding="utf-8", errors="replace").read()
        if path and os.path.isfile(path)
        else None
    )


def req_ids(text):
    ids = []
    for line in (text or "").split("\n"):
        m = re.match(r"^\|\s*(REQ-\d{3})\s*\|", line)
        if m and "withdrawn:" not in line and m.group(1) not in ids:
            ids.append(m.group(1))
    return ids


def parse_backlog(text):
    """id -> {covers, ac, tickets_line, events}; withdrawn stories dropped."""
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
    return {k: v for k, v in stories.items() if k not in withdrawn}


def parse_cases(text):
    """TC id -> set of AC ids, retired rows skipped."""
    cases = {}
    for line in (text or "").split("\n"):
        m = re.match(r"^\|\s*(TC-\d{4})\s*\|", line)
        if not m:
            continue
        cells = [c.strip().lower() for c in line.strip().strip("|").split("|")]
        if "retired" in cells:
            continue
        cases.setdefault(m.group(1), set()).update(AC.findall(line))
    return cases


def parse_log(text):
    """[{sha, subject, body, files}] from the @@commit/@@files format."""
    commits = []
    for block in (text or "").split("@@commit ")[1:]:
        head, _, files = block.partition("@@files")
        lines = head.split("\n")
        sha = lines[0].strip()
        subject = lines[1] if len(lines) > 1 else ""
        body = "\n".join(lines[2:])
        commits.append(
            {
                "sha": sha,
                "subject": subject,
                "body": body,
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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--prd", default="docs/product/PRD.md")
    ap.add_argument("--backlog", default="docs/product/backlog.md")
    ap.add_argument("--cases", default="docs/testing/test-cases.md")
    ap.add_argument("--root", default=".")
    ap.add_argument("--log", default=None)
    ap.add_argument("--adr", default="docs/adr")
    ap.add_argument("--docs", nargs="*", default=["docs/design", "docs/runbooks"])
    ap.add_argument("--events", default="docs/analytics/EVENT_SHEET.md")
    ap.add_argument("--prefix", default="")
    ap.add_argument("--tracker", default="")
    a = ap.parse_args()

    sources_read, missing = 0, []
    prd, backlog, cases_md, sheet = (
        read(a.prd),
        read(a.backlog),
        read(a.cases),
        read(a.events),
    )
    for path, text in ((a.prd, prd), (a.backlog, backlog), (a.cases, cases_md)):
        if text is None:
            missing.append(path)
        else:
            sources_read += 1
    log_text = None
    if a.log == "-":
        log_text = sys.stdin.read()
    elif a.log:
        log_text = read(a.log)
        if log_text is None:
            missing.append(a.log)
    if log_text is not None:
        sources_read += 1

    reqs = req_ids(prd)
    stories = parse_backlog(backlog)
    acs = [ac for st in stories.values() for ac in st["ac"]]
    cases = parse_cases(cases_md)
    commits = parse_log(log_text)
    test_files = walk_tests(a.root)
    tc_in_tests, us_in_tests, tests_linked = set(), set(), 0
    for f in test_files:
        t = read(f) or ""
        ids = set(TC.findall(t))
        tc_in_tests |= ids
        us_in_tests |= set(US.findall(t))
        tests_linked += 1 if ids else 0
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
        ts = set(ticket_re.findall(st["ticket_line"])) if ticket_re else set()
        story_tickets[sid] = ts
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

    # Links and gaps.
    gaps = {
        k: []
        for k in (
            "REQ without story",
            "story without AC",
            "AC without TC",
            "TC without test",
            "story without ticket",
            "ticket without commits",
            "boundary change without ADR",
            "event not in sheet",
            "missing source",
        )
    }
    fix = {
        "REQ without story": "backlog",
        "story without AC": "backlog",
        "AC without TC": "test-cases",
        "TC without test": "write the test, name it with the TC id",
        "story without ticket": "create the ticket, add Ticket: to the story",
        "ticket without commits": "start-task, commit with [<KEY>]",
        "boundary change without ADR": "adr",
        "event not in sheet": "analytics-events",
        "missing source": "the skill that writes it",
    }
    covered = (
        set().union(*(st["covers"] for st in stories.values())) if stories else set()
    )
    l_req_us = sum(1 for r in reqs if r in covered)
    gaps["REQ without story"] = [r for r in reqs if r not in covered]
    gaps["story without AC"] = [s for s, st in stories.items() if not st["ac"]]
    tc_acs = set().union(*cases.values()) if cases else set()
    gaps["AC without TC"] = [ac for ac in acs if ac not in tc_acs]
    gaps["TC without test"] = [t for t in cases if t not in tc_in_tests]
    l_tc_test = len(cases) - len(gaps["TC without test"])
    na = tracker_none or not prefix
    if not na:
        gaps["story without ticket"] = [s for s in stories if not story_tickets[s]]
        subj = (
            set().union(*(c["subject_tickets"] for c in commits)) if commits else set()
        )
        gaps["ticket without commits"] = sorted(
            t for t in known_tickets if t not in subj
        )
    l_us_ticket = sum(1 for s in stories if story_tickets[s])
    l_ticket_commit = sum(
        1 for t in known_tickets if any(t in c["subject_tickets"] for c in commits)
    )
    adr_text = "\n".join(adr_files.values())
    for c in commits:
        touched = [f for f in c["files"] if BOUNDARY.search(f)]
        if not touched:
            continue
        ids = c["tickets"] | c["us"]
        if not ids or not any(i in adr_text for i in ids):
            gaps["boundary change without ADR"].append(f"{c['sha']} ({touched[0]})")
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
            gaps["event not in sheet"].append(f"{e} ({s})")
    if prd is None and stories:
        gaps["missing source"].append(
            f"missing {a.prd}: {len(stories)} stories could not be linked upward (prd)"
        )
    if backlog is None and reqs:
        gaps["missing source"].append(
            f"missing {a.backlog}: {len(reqs)} REQ could not be linked downward (backlog)"
        )
    if cases_md is None and acs:
        gaps["missing source"].append(
            f"missing {a.cases}: {len(acs)} AC could not be linked to a case (test-cases)"
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
            f"traceability: 0 ids and 0 commits read ({a.prd}, {a.backlog}, {a.cases}, log {a.log or 'not given'}), nothing checked",
            file=sys.stderr,
        )
        return 1

    for cls, items in gaps.items():
        for i in items:
            print(f"problem: {cls}: {i} (fix: {fix[cls]})")
    n_ticket = (
        "n/a (tracker: none)" if tracker_none else ("n/a (no prefix)" if na else None)
    )
    k = {cls: len(v) for cls, v in gaps.items()}
    t5 = n_ticket or k["story without ticket"]
    t6 = n_ticket or k["ticket without commits"]
    print(
        f"Ids: REQ {len(reqs)}, US {len(stories)}, AC {len(acs)}, TC {len(cases)}, tests {tests_linked}, "
        f"tickets {len(known_tickets | commit_tickets)}, ADR {len(adr_files)}, events {len(sheet_events)}"
    )
    print(
        f"Links: REQ>US {l_req_us}, US>AC {sum(1 for st in stories.values() if st['ac'])}, "
        f"AC>TC {len(acs) - k['AC without TC']}, TC>test {l_tc_test}, US>ticket {l_us_ticket}, "
        f"ticket>commit {l_ticket_commit}, US>docs {l_us_docs}, US>event {l_us_event} "
        f"(US ids in tests, weaker: {len(us_in_tests & set(stories))})"
    )
    print(
        f"Gaps: REQ without story {k['REQ without story']}, story without AC {k['story without AC']}, "
        f"AC without TC {k['AC without TC']}, TC without test {k['TC without test']}, "
        f"story without ticket {t5}, ticket without commits {t6}, "
        f"boundary change without ADR {k['boundary change without ADR']}, "
        f"event not in sheet {k['event not in sheet']}, missing source {k['missing source']}"
    )
    print(
        f"Unknown tickets: {len(unknown_tickets)}{' (' + ', '.join(unknown_tickets) + ')' if unknown_tickets else ''}"
    )
    total = sum(k.values())
    classes = sum(1 for v in k.values() if v)
    pfx = f"{prefix}{' inferred' if inferred else ''}" if prefix else "none"
    print(
        f"traceability: {sources_read} sources read, {len(missing)} missing, {len(commits)} commits, "
        f"{len(test_files)} test files, prefix {pfx}, {total} gaps in {classes} classes"
    )
    print(
        f"Verdict: {'traced' if total == 0 else f'not traced ({total} gaps in {classes} classes)'}"
    )
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
