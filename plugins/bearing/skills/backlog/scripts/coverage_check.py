#!/usr/bin/env python3
"""coverage_check: prove every PRD statement is covered by an acceptance
criterion, and that the backlog, its tasks and its open-question register
hold together. Computed from the files, never from what the model wrote
about them.

Id scheme:
  - The backlog's own. A backlog committed at HEAD fixes the scheme (its
    story headings, for example CLM-7 or PAY-112); otherwise the headings
    in the working file do; with neither, the house scheme US-nn-nnn.
    `--story-id REGEX` overrides. Every story id at HEAD must still be a
    story heading now: a renumbered or dropped id is a problem.
  - AC ids are `AC-<story>-k`, or `AC-k` inside the story's own block.
  - House scheme (US-nn-nnn) is strict: every AC carries its own Covers
    line and every story has the house blocks (below). An adopted scheme
    keeps its own shape: a story whose AC carry no Covers lines is traced
    by its story-level Covers line or its index row's Covers cell, and the
    house blocks are not required.

Coverage:
  - REQ ids: the PRD's statement rows (`| REQ-nnn |`), skipping rows marked
    `withdrawn:`; with no PRD, the "Statements (inline" table at the top of
    coverage.md.
  - A REQ is covered when a story that is not withdrawn names it on an AC
    Covers line (or, adopted scheme, at story level as above). A REQ the
    coverage matrix judges `out-of-scope`, citing a Q-nnn in its Why cell,
    is counted apart and is not a gap.
  - A story-level Covers REQ that none of the story's own AC names (when
    its AC carry Covers lines), a Covers naming a REQ the PRD does not have
    or has withdrawn, and a story with more than seven AC are problems.
  - An epic with no journey in user-flows.md is a problem, when the file
    exists.
  - The coverage.md matrix, when present, holds one row per REQ; each
    row's Judgement is one of story, criterion-of, platform-detail-of,
    duplicate-of, split, non-functional or out-of-scope, and its Why cell
    is not blank.

Withdrawn stories:
  - A story is withdrawn when its heading or a Status line says
    `withdrawn:`, or its index row's Status cell says withdrawn. It stays in
    the file; it covers nothing.
  - Inside a git repository, every file outside docs/ that names a
    withdrawn story (code, tests, config) is listed, and each such story
    must be named in the open-question register (questions.md, or a Q row
    in the backlog) so someone decides what happens to that work.

Stories (house scheme only):
  - Each live story has a "Why it matters" line naming a business objective
    (B1, B2 ...) from the PRD's objectives table, when the PRD has one; a
    "From the PRD" block quoting every REQ the story covers; a "Not in this
    story" list with at least one entry; and a Points value of 1, 2, 3, 5, 8
    or TBD.
  - The story index (the table headed `| Story |`) lists every live story
    once, with the same Points as the story block. (Any scheme: every live
    story has an index row when the backlog has an index.)

Tasks (tasks.md, the table headed `| Task |`), checked when --tasks is
given or the default file exists:
  - Ids are <story>-Dk (development) or <story>-Tk (test), unique, of a
    live story named in the Story column. Discipline is backend, frontend,
    mobile, qa, devops, design or content (deliverables that are not code:
    brand, video, copy), and a test task is qa. Estimate is hours (above 0,
    at most 8; more is a task to split) or TBD. Depends on names known task
    ids or none. Done when is not blank. Verifies names AC ids of the same
    story, or `none: <reason>` on a development task.
  - Every live story has a development and a test task, and every live AC
    is verified by a test task.

Questions (questions.md, the table headed `| Q |`), checked when
--questions is given or the default file exists:
  - Ids Q-nnn, unique. Status open or confirmed; Kind open-question, gap or
    contradiction; Basis stated, inferred, convention or assumption. Where,
    Question, Readings, Decision and Why are not blank. Affects names at
    least one story of the backlog and no unknown one.
  - The "Needs your confirmation" section lists exactly the open rows whose
    Basis is assumption, and those rows come first in the table.

Usage: coverage_check.py [--prd P] [--backlog B] [--coverage C] [--flows F]
                         [--tasks T] [--questions Q] [--story-id REGEX]
Defaults are the docs/product/ paths. Prints one line per gap or problem,
the ids, withdrawn-refs, tasks and questions lines, the counts and the
verdict; exits 1 on any gap or problem, or when zero REQ or zero stories
were read, or a task or question file that was asked for is missing or
empty.
"""

import argparse
import collections
import os
import re
import subprocess
import sys

REQ = re.compile(r"\bREQ-\d{3}\b")
EPIC_H = re.compile(r"^#{2,4}\s+(EP-\d{2})\b")
Q_ID = re.compile(r"\bQ-\d+\b")
OBJ = re.compile(r"\bB\d+\b")
HOUSE = r"US-\d{2}-\d{3}"
MAX_AC = 7
POINTS = {"1", "2", "3", "5", "8", "TBD"}
DISCIPLINES = {"backend", "frontend", "mobile", "qa", "devops", "design", "content"}
JUDGEMENTS = {
    "story",
    "criterion-of",
    "platform-detail-of",
    "duplicate-of",
    "split",
    "non-functional",
    "out-of-scope",
}
KINDS = {"open-question", "gap", "contradiction"}
BASES = {"stated", "inferred", "convention", "assumption"}
STATUSES = {"open", "confirmed"}
SKIP_DIRS = {
    ".git",
    "docs",
    "node_modules",
    "__pycache__",
    ".venv",
    "venv",
    "dist",
    "build",
    ".scratch",
    ".pytest_cache",
    "vendor",
}


def strip_comments(text):
    return re.sub(r"<!--.*?-->", "", text, flags=re.S)


def read(path):
    """The file's text with HTML comments (template guidance) removed."""
    if not path or not os.path.isfile(path):
        return None
    return strip_comments(open(path, encoding="utf-8").read())


def cells(line):
    return [c.strip() for c in line.strip().strip("|").split("|")]


def table(text, head, row):
    """(lower-cased header, rows) of the table whose first header cell is
    `head`, rows being the lines whose first cell matches `row`."""
    header, rows = None, []
    for line in (text or "").split("\n"):
        if not line.startswith("|"):
            continue
        c = cells(line)
        if c and c[0] == head:
            header = [x.lower() for x in c]
        elif header is not None and c and re.match(row, c[0]):
            rows.append(c)
    return header, rows


def col(header, row, name):
    """The cell whose header starts with `name`, or ''."""
    for i, h in enumerate(header or []):
        if h.startswith(name):
            return row[i] if i < len(row) else ""
    return ""


class Scheme:
    """The backlog's story id scheme and the ids derived from it."""

    def __init__(self, pat):
        self.pat = pat
        self.house = pat == HOUSE
        self.story_h = re.compile(r"^#{2,4}\s+(" + pat + r")(?![\w-])(.*)$")
        self.story_id = re.compile(r"(?<![\w-])(" + pat + r")(?![\w-])")
        self.row = r"^(" + pat + r")$"
        self.task_id = re.compile(r"^(" + pat + r")-([DT])(\d+)$")
        self.ac_id = re.compile(r"(?<![\w-])AC-(?:(" + pat + r")-)?(\d+)(?![\w-])")

    def acs(self, text):
        """Qualified AC ids named in `text` (a tasks cell): AC-<story>-k."""
        return [f"AC-{s}-{k}" for s, k in self.ac_id.findall(text) if s]


def detect_scheme(texts):
    """The story id pattern of the first text whose headings show one."""
    for text in texts:
        if not text:
            continue
        heads = [
            h
            for h in re.findall(
                r"^#{2,4}\s+([A-Z][A-Z0-9]*(?:-\d+)+)(?![\w-])", text, re.M
            )
            if not re.fullmatch(r"EP-\d{2}", h)
        ]
        if not heads:
            continue
        if any(re.fullmatch(HOUSE, h) for h in heads):
            return HOUSE
        prefix = collections.Counter(h.split("-", 1)[0] for h in heads).most_common(1)[
            0
        ][0]
        return re.escape(prefix) + r"-\d+"
    return HOUSE


def git(cwd, *args):
    try:
        out = subprocess.run(
            ["git", "-C", cwd, *args], capture_output=True, text=True, timeout=30
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    return out.stdout if out.returncode == 0 else None


def req_ids(prd, coverage):
    """REQ ids from statement rows; (ids, withdrawn, source)."""
    for src, text, marker in (
        (prd, read(prd), None),
        (coverage, read(coverage), "Statements (inline"),
    ):
        if text is None:
            continue
        if marker:
            i = text.find(marker)
            if i < 0:
                continue
            text = text[i:].split("\n## ", 1)[0]
        ids, withdrawn = [], set()
        for line in text.split("\n"):
            m = re.match(r"^\|\s*(REQ-\d{3})\s*\|", line)
            if not m:
                continue
            if "withdrawn:" in line:
                withdrawn.add(m.group(1))
            elif m.group(1) not in ids:
                ids.append(m.group(1))
        if ids or withdrawn:
            return ids, withdrawn, src
    return [], set(), None


def block(lines, label):
    """Text of the bold-labelled block `**<label>.**` up to the next one."""
    out, on = [], False
    for line in lines:
        s = line.strip()
        if s.startswith("**"):
            if on:
                break
            if s.lower().startswith("**" + label.lower()):
                on = True
                out.append(s.split("**", 2)[-1])
                continue
        if on:
            out.append(line)
    return "\n".join(out) if on else None


def parse_backlog(text, sc):
    """stories: id -> {epic, title, withdrawn, covers, ac: {id: set(REQ)},
    lines}, in file order; and the epic ids."""
    stories, epics = {}, []
    epic = story = ac = None
    for line in text.split("\n"):
        e = EPIC_H.match(line)
        if e:
            epic, story, ac = e.group(1), None, None
            if epic not in epics:
                epics.append(epic)
            continue
        s = sc.story_h.match(line)
        if s:
            story, ac = s.group(1), None
            stories[story] = {
                "epic": epic,
                "title": s.group(2).strip(),
                "withdrawn": "withdrawn:" in s.group(2),
                "covers": set(),
                "ac": {},
                "lines": [],
            }
            continue
        if re.match(r"^#{1,3}\s", line):
            story = ac = None
            continue
        if story is None:
            continue
        st = stories[story]
        st["lines"].append(line)
        if "withdrawn:" in line and line.lstrip().startswith(("Status", "withdrawn:")):
            st["withdrawn"] = True
        a = sc.ac_id.search(line)
        if a and (a.group(1) in (None, story)):
            ac = f"AC-{story}-{a.group(2)}"
            st["ac"].setdefault(ac, set())
        if "Covers:" in line:
            reqs = set(REQ.findall(line.split("Covers:", 1)[1]))
            if ac:
                st["ac"][ac] |= reqs
            else:
                st["covers"] |= reqs
    return stories, epics


def index_rows(text, sc):
    header, rows = table(text, "Story", sc.row)
    return header, rows


def apply_index(stories, header, rows, strict):
    """Index Status cells mark stories withdrawn; in an adopted scheme the
    index Covers cell traces a story whose AC carry no Covers lines."""
    for r in rows:
        st = stories.get(r[0])
        if st is None:
            continue
        status = col(header, r, "status")
        if re.search(r"\bwithdrawn\b", status, re.I):
            st["withdrawn"] = True
        if not strict:
            cov = col(header, r, "covers")
            if cov and not cov.lower().startswith("inferred"):
                st["index_covers"] = set(REQ.findall(cov))


def check_house_blocks(live, objectives, header, rows, problems):
    for sid, st in live.items():
        lines = st["lines"]
        why = block(lines, "Why it matters")
        if why is None or not why.strip():
            problems.append(f"{sid}: no 'Why it matters' line")
        elif objectives:
            named = set(OBJ.findall(why))
            if not named:
                problems.append(
                    f"{sid}: 'Why it matters' names no business objective from the PRD"
                )
            for b in sorted(named - objectives):
                problems.append(f"{sid}: {b} is not a business objective in the PRD")
        quoted = block(lines, "From the PRD")
        if quoted is None:
            problems.append(f"{sid}: no 'From the PRD' block")
        else:
            for r in sorted(st["covers"] - set(REQ.findall(quoted))):
                problems.append(
                    f"{sid}: covers {r} but 'From the PRD' does not quote it"
                )
        notin = block(lines, "Not in this story")
        if notin is None or not re.search(r"^\s*-\s+\S", notin, re.M):
            problems.append(f"{sid}: 'Not in this story' has no entry")
        pts = re.search(r"\bPoints:\s*(\S+)", "\n".join(lines))
        st["points"] = pts.group(1) if pts else None
        if st["points"] not in POINTS:
            problems.append(
                f"{sid}: Points is '{st['points'] or 'missing'}', want 1, 2, 3, 5, 8 or TBD"
            )
    for r in rows:
        sid = r[0]
        if sid in live and live[sid].get("points"):
            pts = col(header, r, "points")
            if pts != live[sid]["points"]:
                problems.append(
                    f"story index: {sid} Points '{pts}' differs from the story's '{live[sid]['points']}'"
                )


def check_index(live, stories, header, rows, strict, problems):
    if header is None:
        if strict:
            problems.append("backlog: no story index (a table headed | Story |)")
        return
    seen = set()
    for r in rows:
        sid = r[0]
        if sid in seen:
            problems.append(f"story index: {sid} listed twice")
        seen.add(sid)
        if sid not in stories:
            if "withdrawn" not in " ".join(r).lower():
                problems.append(f"story index: {sid} has no story block in the backlog")
        elif sid not in live and strict and "withdrawn" not in " ".join(r).lower():
            problems.append(f"story index: {sid} is not a live story in the backlog")
    for sid in live:
        if sid not in seen:
            problems.append(f"story index: {sid} has no row")


def check_tasks(path, live, sc, problems):
    """(task count, development, test, hours by discipline, TBD) or None."""
    text = read(path)
    if text is None:
        problems.append(
            f"no tasks at {path} (every story needs development and test tasks)"
        )
        return None
    header, rows = table(text, "Task", r"^" + sc.pat + r"-")
    if header is None or not rows:
        problems.append(f"{path}: 0 task rows (a table headed | Task |)")
        return None
    need = ["story", "discipline", "estimate", "depends on", "done when", "verifies"]
    missing = [n for n in need if not any(h.startswith(n) for h in header)]
    if missing:
        problems.append(f"{path}: no '{missing[0]}' column")
        return None
    ids = {r[0] for r in rows}
    seen, dev, test, tbd = set(), 0, 0, 0
    hours = {}
    has = {sid: set() for sid in live}
    verified = set()
    for r in rows:
        tid = r[0]
        m = sc.task_id.match(tid)
        if not m:
            problems.append(f"{tid}: id is not <story>-Dk or <story>-Tk")
            continue
        if tid in seen:
            problems.append(f"{tid}: duplicate id")
        seen.add(tid)
        sid, kind = m.group(1), m.group(2)
        if col(header, r, "story") != sid:
            problems.append(
                f"{tid}: Story column '{col(header, r, 'story')}' is not {sid}"
            )
        if sid not in live:
            problems.append(f"{tid}: {sid} is not a live story")
            continue
        has[sid].add(kind)
        disc = col(header, r, "discipline").lower()
        if disc not in DISCIPLINES:
            problems.append(
                f"{tid}: discipline '{disc}' is not one of {', '.join(sorted(DISCIPLINES))}"
            )
        elif kind == "T" and disc != "qa":
            problems.append(f"{tid}: a test task is qa, not {disc}")
        est = col(header, r, "estimate")
        if est.upper() == "TBD":
            tbd += 1
        else:
            try:
                h = float(est.lower().rstrip("h").strip())
            except ValueError:
                h = None
            if h is None or h <= 0:
                problems.append(f"{tid}: estimate '{est}' is not hours or TBD")
            elif h > 8:
                problems.append(f"{tid}: {h:g} h is over a day; split the task")
            else:
                hours[disc] = hours.get(disc, 0) + h
        dep = col(header, r, "depends on")
        if not dep:
            problems.append(f"{tid}: Depends on is blank (write none)")
        elif dep.lower() != "none":
            for d in re.split(r"[,\s]+", dep):
                if d and d not in ids:
                    problems.append(f"{tid}: depends on {d}, which is not a task")
        if not col(header, r, "done when"):
            problems.append(f"{tid}: Done when is blank")
        ver = col(header, r, "verifies")
        acs = sc.acs(ver)
        for ac in acs:
            if ac not in live[sid]["ac"]:
                problems.append(f"{tid}: verifies {ac}, which is not an AC of {sid}")
        if kind == "T":
            test += 1
            if not acs:
                problems.append(f"{tid}: a test task verifies no AC")
            verified.update(acs)
        else:
            dev += 1
            if not acs and not re.match(r"^none:\s*\S", ver, re.I):
                problems.append(f"{tid}: Verifies names no AC (or none: <reason>)")
    for sid, kinds in has.items():
        for k, word in (("D", "development"), ("T", "test")):
            if k not in kinds:
                problems.append(f"{sid}: no {word} task in {path}")
        for ac in live[sid]["ac"]:
            if ac not in verified:
                problems.append(f"{ac}: no test task verifies it")
    return len(seen), dev, test, hours, tbd


def check_questions(path, stories, reqs, sc, problems):
    """(rows, open assumptions, open) or None."""
    text = read(path)
    if text is None:
        problems.append(f"no questions register at {path}")
        return None
    header, rows = table(text, "Q", r"^Q-\d+$")
    if header is None or not rows:
        if re.search(r"^No open questions", text, re.M):
            return 0, 0, 0
        problems.append(
            f"{path}: 0 Q-nnn rows (write 'No open questions' when there are none)"
        )
        return None
    seen, assumed, n_open = set(), [], 0
    first_other = None
    for r in rows:
        q = r[0]
        if q in seen:
            problems.append(f"{q}: duplicate id")
        seen.add(q)
        status = col(header, r, "status").lower()
        kind = col(header, r, "kind").lower()
        basis = col(header, r, "basis").lower()
        if status not in STATUSES:
            problems.append(f"{q}: status '{status}' is not open or confirmed")
        if kind not in KINDS:
            problems.append(
                f"{q}: kind '{kind}' is not open-question, gap or contradiction"
            )
        if basis not in BASES:
            problems.append(
                f"{q}: basis '{basis}' is not stated, inferred, convention or assumption"
            )
        for name in ("where", "question", "readings", "decision", "why"):
            if not col(header, r, name):
                problems.append(f"{q}: {name.title()} is blank")
        for rq in REQ.findall(col(header, r, "where")):
            if rq not in reqs:
                problems.append(f"{q}: Where names {rq}, which is not a PRD statement")
        aff = sc.story_id.findall(col(header, r, "affects"))
        if not aff:
            problems.append(f"{q}: Affects names no story")
        for s in aff:
            if s not in stories:
                problems.append(
                    f"{q}: Affects names {s}, which is not a story in the backlog"
                )
        if status == "open":
            n_open += 1
        if status == "open" and basis == "assumption":
            assumed.append(q)
            if first_other is not None:
                problems.append(
                    f"{q}: an open assumption listed after {first_other}; assumptions come first"
                )
        elif first_other is None:
            first_other = q
    m = re.search(
        r"^##\s+Needs your confirmation.*?$(.*?)(?=^## |\Z)", text, re.M | re.S
    )
    listed = set(Q_ID.findall(m.group(1))) if m else set()
    if assumed and not m:
        problems.append(
            f"{path}: no 'Needs your confirmation' section for {len(assumed)} open assumptions"
        )
    for q in assumed:
        if m and q not in listed:
            problems.append(
                f"{q}: open assumption missing from 'Needs your confirmation'"
            )
    for q in sorted(listed - set(assumed)):
        problems.append(
            f"{q}: under 'Needs your confirmation' but not an open assumption in the register"
        )
    return len(seen), len(assumed), n_open


def dod_reqs(backlog, sc):
    """REQ ids a definition of done carries: named in a paragraph outside
    any story block that mentions the definition of done."""
    outside, inside = [], False
    for line in backlog.split("\n"):
        if sc.story_h.match(line):
            inside = True
        elif re.match(r"^#{1,3}\s", line) and not EPIC_H.match(line):
            inside = False
        if not inside:
            outside.append(line)
    found = set()
    rows = [line for line in outside if line.lstrip().startswith("|")]
    prose = "\n".join(line for line in outside if not line.lstrip().startswith("|"))
    for para in re.split(r"\n\s*\n", prose) + rows:
        if re.search(r"definition of done", para, re.I):
            found |= set(REQ.findall(para))
    return found


def withdrawn_refs(root, withdrawn, sc):
    """{story: ['path:line', ...]} for files outside docs/ naming it."""
    refs = {s: [] for s in withdrawn}
    if not root or not withdrawn:
        return refs
    for d, dirs, files in os.walk(root):
        dirs[:] = [x for x in dirs if x not in SKIP_DIRS and not x.startswith(".")]
        for f in files:
            p = os.path.join(d, f)
            try:
                if os.path.getsize(p) > 1_000_000:
                    continue
                with open(p, encoding="utf-8") as fh:
                    lines = fh.read().split("\n")
            except (OSError, UnicodeDecodeError):
                continue
            for n, line in enumerate(lines, 1):
                for s in set(sc.story_id.findall(line)) & withdrawn:
                    refs[s].append(f"{os.path.relpath(p, root)}:{n}")
    return refs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--prd", default="docs/product/PRD.md")
    ap.add_argument("--backlog", default="docs/product/backlog.md")
    ap.add_argument("--coverage", default="docs/product/coverage.md")
    ap.add_argument("--flows", default="docs/product/user-flows.md")
    ap.add_argument("--tasks", default=None)
    ap.add_argument("--questions", default=None)
    ap.add_argument(
        "--story-id",
        default=None,
        help="regex of a story id, when the backlog's scheme is not detected",
    )
    a = ap.parse_args()
    tasks_path = a.tasks or "docs/product/tasks.md"
    q_path = a.questions or "docs/product/questions.md"
    want_tasks = a.tasks is not None or os.path.isfile(tasks_path)
    want_q = a.questions is not None or os.path.isfile(q_path)

    reqs, withdrawn, src = req_ids(a.prd, a.coverage)
    backlog = read(a.backlog)
    if not reqs:
        print(
            f"stories-coverage: 0 REQ statements read ({a.prd}, {a.coverage}), nothing checked",
            file=sys.stderr,
        )
        return 1
    if backlog is None:
        print(
            f"stories-coverage: no backlog at {a.backlog}, nothing checked",
            file=sys.stderr,
        )
        return 1

    bdir = os.path.dirname(os.path.abspath(a.backlog))
    root = (git(bdir, "rev-parse", "--show-toplevel") or "").strip() or None
    base = None
    if root:
        rel = os.path.relpath(os.path.abspath(a.backlog), root)
        shown = git(root, "show", f"HEAD:{rel}")
        base = strip_comments(shown) if shown is not None else None
    sc = Scheme(a.story_id or detect_scheme([base, backlog]))
    strict = sc.house

    stories, epics = parse_backlog(backlog, sc)
    header, rows = index_rows(backlog, sc)
    apply_index(stories, header, rows, strict)
    live = {k: v for k, v in stories.items() if not v["withdrawn"]}
    if not live:
        hint = ""
        if base is not None and parse_backlog(base, sc)[0]:
            hint = "; the committed backlog has stories in this scheme, so its ids were renumbered or dropped"
        print(
            f"stories-coverage: 0 stories in {a.backlog} (ids {sc.pat}){hint}, nothing checked",
            file=sys.stderr,
        )
        return 1

    problems = []
    ids_line = "ids: no committed backlog, nothing compared"
    if base is not None:
        before, _ = parse_backlog(base, sc)
        bh, br = index_rows(base, sc)
        apply_index(before, bh, br, strict)
        gone = [s for s in before if s not in stories]
        for s in gone:
            problems.append(
                f"{s}: a story id at HEAD is no longer a story heading (ids are never renumbered or dropped; mark it withdrawn: in place)"
            )
        for s in before:
            if before[s]["withdrawn"] and s in live:
                problems.append(
                    f"{s}: withdrawn at HEAD, live now (a withdrawn id is never reused)"
                )
        changed = [
            s
            for s in before
            if s in stories
            and "\n".join([before[s]["title"]] + before[s]["lines"]).strip()
            != "\n".join([stories[s]["title"]] + stories[s]["lines"]).strip()
        ]
        new = [s for s in stories if s not in before]
        ids_line = (
            f"ids: {len(before) - len(gone)} of {len(before)} kept from HEAD, {len(new)} new"
            f" ({', '.join(new) or 'none'}), changed since HEAD: {', '.join(changed) or 'none'}"
        )

    qtext = (read(q_path) or "") if want_q else ""
    backlog_q_rows = "\n".join(
        line for line in backlog.split("\n") if re.match(r"^\|\s*Q-\d+\s*\|", line)
    )
    register = qtext + "\n" + backlog_q_rows

    def raised(story, req=None):
        """A register line names the story (and the REQ, when given)."""
        sid_re = re.compile(r"(?<![\w-])" + re.escape(story) + r"(?![\w-])")
        return any(
            sid_re.search(line) and (req is None or req in line)
            for line in register.split("\n")
        )

    covered_by = {r: [] for r in reqs}
    for r in dod_reqs(backlog, sc):
        if r in covered_by:
            covered_by[r].append("definition of done")
    n_ac = 0
    orphans, story_traced = [], []
    for sid, st in live.items():
        n_ac += len(st["ac"])
        ac_reqs = set().union(*st["ac"].values()) if st["ac"] else set()
        if len(st["ac"]) > MAX_AC:
            problems.append(
                f"{sid}: {len(st['ac'])} acceptance criteria, over {MAX_AC} (split the story)"
            )
        if not st["ac"]:
            problems.append(f"{sid}: no acceptance criteria")
        story_level = st["covers"] | st.get("index_covers", set())
        if not strict:
            if story_level - ac_reqs:
                story_traced.append(sid)
            named = ac_reqs | story_level
            where = dict(st["ac"])
            where[sid] = story_level
        else:
            named = ac_reqs
            where = st["ac"]
            for r in sorted(st["covers"] - ac_reqs):
                problems.append(f"{sid}: story covers {r} but none of its AC names it")
            for ac, rs in st["ac"].items():
                if not rs:
                    problems.append(f"{ac}: no Covers: line")
        for ac, rs in where.items():
            for r in sorted(rs):
                if r in covered_by:
                    covered_by[r].append(sid)
                elif r in withdrawn:
                    if not raised(sid, r):
                        problems.append(
                            f"{ac}: covers {r}, which the PRD marks withdrawn: (mark {sid} withdrawn: in place, or raise a Q-nnn naming {sid} and {r} while the team decides)"
                        )
                else:
                    problems.append(f"{ac}: covers {r}, which is not a PRD statement")
        if not (named | st["covers"]):
            orphans.append(sid)

    if strict:
        objectives = set(re.findall(r"^\|\s*(B\d+)\s*\|", read(a.prd) or "", re.M))
        check_house_blocks(live, objectives, header, rows, problems)
    check_index(live, stories, header, rows, strict, problems)

    flows = read(a.flows)
    if flows is not None:
        for ep in epics:
            if ep in {s["epic"] for s in live.values()} and ep not in flows:
                problems.append(f"{ep}: no journey in {a.flows}")

    q_ids = set(Q_ID.findall(qtext)) | set(Q_ID.findall(backlog_q_rows))
    out_of_scope = set()
    cov = read(a.coverage)
    if cov is not None:
        matrix = cov.split("## Gaps", 1)[0].split("## Matrix", 1)[-1]
        mh, mrows = table(matrix, "REQ", r"^REQ-\d{3}$")
        got = set()
        for r in mrows:
            rq = r[0]
            got.add(rq)
            judgement = col(mh, r, "judgement")
            word = judgement.split(" ", 1)[0].lower() if judgement else ""
            if word not in JUDGEMENTS:
                problems.append(
                    f"{rq}: judgement '{judgement}' is not one of {', '.join(sorted(JUDGEMENTS))}"
                )
            why = col(mh, r, "why")
            if not why:
                problems.append(f"{rq}: the matrix row has no Why")
            if word == "out-of-scope":
                cited = set(Q_ID.findall(why))
                if not cited:
                    problems.append(f"{rq}: out-of-scope with no Q-nnn decision in Why")
                for q in sorted(cited - q_ids):
                    problems.append(
                        f"{rq}: Why cites {q}, which is not in {q_path} or the backlog's question rows"
                    )
                if covered_by.get(rq):
                    problems.append(f"{rq}: judged out-of-scope but an AC covers it")
                else:
                    out_of_scope.add(rq)
        for r in reqs:
            if r not in got:
                problems.append(f"{r}: no row in the {a.coverage} matrix")

    dead = {s for s, st in stories.items() if st["withdrawn"]}
    refs = withdrawn_refs(root, dead, sc)
    for s in sorted(refs):
        if refs[s] and not raised(s):
            problems.append(
                f"{s}: withdrawn, but {', '.join(refs[s][:5])} still name it; raise a Q-nnn on what happens to that work"
            )
    n_refs = sum(len(v) for v in refs.values())
    refs_line = (
        f"withdrawn-refs: {len(dead)} withdrawn stories, {n_refs} references in files outside docs/"
        + ("" if root else " (not scanned: not a git repository)")
    )

    tasks = check_tasks(tasks_path, live, sc, problems) if want_tasks else None
    questions = (
        check_questions(q_path, stories, set(reqs), sc, problems) if want_q else None
    )

    gaps = [r for r in reqs if not covered_by[r] and r not in out_of_scope]
    for r in gaps:
        print(f"gap: {r} has no acceptance criterion covering it")
    for p in problems:
        print(f"problem: {p}")
    for o in orphans:
        print(
            f"orphan: {o} covers no REQ (mark inferred: for the user to accept or drop)"
        )
    print(ids_line)
    print(refs_line)
    if tasks:
        n, dev, test, hours, tbd = tasks
        by = ", ".join(f"{d} {hours[d]:g}" for d in sorted(hours)) or "none estimated"
        print(
            f"tasks: {n} ({dev} development, {test} test), hours by discipline: {by}; "
            f"total {sum(hours.values()):g} h, {tbd} TBD"
        )
    elif not want_tasks:
        print("tasks: not written (stories only)")
    if questions:
        n, assumed, n_open = questions
        print(f"questions: {n} (open {n_open}, needs confirmation {assumed})")
    elif not want_q:
        print(f"questions: no register at {q_path}")
    traced = f", {len(story_traced)} traced at story level" if story_traced else ""
    print(
        f"stories-coverage: {len(reqs)} REQ from {src} ({len(withdrawn)} withdrawn), "
        f"{len(reqs) - len(gaps) - len(out_of_scope)} covered, {len(out_of_scope)} out of scope, "
        f"{len(gaps)} gaps, {len(live)} stories, {n_ac} AC, {len(orphans)} orphans, "
        f"{len(problems)} problems{traced}"
    )
    print(f"Verdict: {'covered' if not gaps and not problems else 'not covered'}")
    return 1 if gaps or problems else 0


if __name__ == "__main__":
    sys.exit(main())
