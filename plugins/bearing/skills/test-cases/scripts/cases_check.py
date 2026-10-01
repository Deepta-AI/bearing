#!/usr/bin/env python3
"""cases_check: every acceptance criterion has cases, and every case says how
it will be verified, counted from the files.

  - Criteria: the AC ids (AC-US-nn-nnn-k, AC-US-LOCAL-nnn-k) in the backlog,
    skipping stories marked withdrawn: in the heading or on a Status line.
    With --story, only that story's.
  - Cases: the rows of the test-case table (| TC-nnnn | ...), status
    `retired` excluded. A duplicate TC id is a problem.
  - Coverage: an AC id with no live row is a problem.
  - Oracles: the table's Oracles column, designed after the scenarios, holds
    tagged checks separated by ";": ui: (what the user sees), data:
    (persisted state read back), not: (what must not happen), effect: (an
    event, a message, a log line), inv: (an invariant that must hold). Every
    live row needs one; a P1 row needs two categories, one of them not:. A
    check that says only "works", "succeeds", "correct" or "as expected" is
    not a check.
  - Risks: the register (| R-nnn | ...) rates each risk's likelihood and
    impact (L, M, H) and its level follows from them: High when one is H and
    the other at least M, Low when both are L or one is L and the other M,
    Medium otherwise. Every story in scope has a risk, every threat id (T-nn)
    in the threat models is the source of one, and the level sets the depth
    of its live cases: High needs three, one with a not: oracle and one of
    type integration or e2e; Medium needs two, one with not:; Low needs one.

  - Types: a test-types line counts the live cases by type and by who runs
    them (a machine: automated or planned; a person: manual type or
    manual-only), always printed.
  - Steps (--steps F): the step table (| Step | Case | Action | Expected |,
    step ids TC-nnnn.k) gives every live manual or e2e case at least one
    step; every step names a live case, its id matches its case, and its
    Action and Expected are written and specific.
  - Plan (--plan F): the test plan quotes this run's test-cases and
    test-types lines verbatim; has the Entry criteria, Exit criteria,
    Environments and "What QA raised" sections; its scenario rows
    (| Scenario | ... | Proves that | ... | Cases |, ids TS-US-nn-nnn-k)
    each say what they prove and name live cases, cover every story in
    scope and every live case, and match its "Scenarios: N" line; every
    concern QA raised is tagged [assumption], [untestable], [undefined],
    [contradiction] or [risk]; and it claims every criterion has a case
    only when none lacks one.

Usage: cases_check.py [--backlog B] [--cases C] [--risks R]
                      [--threats GLOB] [--story US-nn-nnn]
                      [--steps F] [--plan F]
Prints one line per problem, the types line, the steps and plan lines when
asked, and the counts last; exits 1 on any problem, or when zero criteria,
zero cases or zero risks were read, or a named steps or plan file is
missing or empty.
"""

import argparse
import glob
import os
import re
import sys

AC_RE = re.compile(r"\bAC-US-(?:\d{2}-\d{3}|LOCAL-\d{3})-\d+\b")
TAGS = ("ui", "data", "not", "effect", "inv")
VAGUE = re.compile(
    r"^\s*(it\s+)?(works|succeeds|is correct|correct|as expected|passes|ok)\.?\s*$",
    re.I,
)


def split_checks(text):
    """Split an Oracles cell on ";" outside quotes, so quoted copy that holds a
    semicolon ("Saved; we will call you") stays one check."""
    parts, cur, quote = [], "", None
    for ch in text:
        if quote:
            if ch == quote:
                quote = None
        elif ch in "\"\u201c":
            quote = "\"" if ch == "\"" else "\u201d"
        elif ch == ";":
            parts.append(cur)
            cur = ""
            continue
        cur += ch
    parts.append(cur)
    return parts


def read(p):
    return open(p, encoding="utf-8").read() if os.path.isfile(p) else None


HEAD_RE = re.compile(r"^#{2,4}\s+(US-(?:\d{2}-\d{3}|LOCAL-\d{3}))\b(.*)$")


def withdrawn_ids(text):
    """Stories marked withdrawn, the way the backlog gate reads them: in the
    heading, or on a `Status: withdrawn:` line inside the story."""
    out, cur = set(), None
    for line in text.split("\n"):
        h = HEAD_RE.match(line)
        if h:
            cur = h.group(1)
            if "withdrawn:" in h.group(2):
                out.add(cur)
            continue
        if cur and re.match(r"^\s*\**Status\**:?\**\s*withdrawn:", line, re.I):
            out.add(cur)
    return out


def criteria(text, story):
    acs, cur, gone = [], None, withdrawn_ids(text)
    for line in text.split("\n"):
        h = HEAD_RE.match(line)
        if h:
            cur = h.group(1)
            continue
        if cur in gone or (story and cur != story):
            continue
        for ac in AC_RE.findall(line):
            if ac not in acs:
                acs.append(ac)
    return acs


def table(text, head="TC", row=r"^TC-\d{4}$"):
    """(header cells, rows as lists of cells) of the table whose first
    column is headed `head` and whose rows start with an id matching `row`."""
    header, rows = None, []
    for line in text.split("\n"):
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if cells and cells[0] == head:
            header = [c.lower() for c in cells]
        elif cells and re.match(row, cells[0]):
            rows.append(cells)
    return header, rows


STORY_RE = re.compile(r"\bUS-(?:\d{2}-\d{3}|LOCAL-\d{3})\b")
THREAT_RE = re.compile(r"\bT-\d{2,3}\b")
RATE = {"L": 1, "M": 2, "H": 3}
DEPTH = {"high": 3, "medium": 2, "low": 1}


def level(likelihood, impact):
    """The level the likelihood and impact give: High, Medium or Low."""
    a, b = sorted((RATE[likelihood], RATE[impact]))
    if b == 3 and a >= 2:
        return "high"
    if b <= 2 and a == 1:
        return "low"
    return "medium"


def stories(text, story):
    """Story ids in the backlog, skipping withdrawn ones."""
    out, gone = [], withdrawn_ids(text)
    for line in text.split("\n"):
        h = HEAD_RE.match(line)
        if h and h.group(1) not in gone and (not story or h.group(1) == story):
            out.append(h.group(1))
    return out


def threats(pattern):
    """(files read, threat ids with a likelihood) from the threat models;
    a "considered, none" row has no likelihood and is not a threat."""
    files, ids = [], []
    for f in sorted(glob.glob(pattern)):
        files.append(f)
        for line in open(f, encoding="utf-8"):
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if line.startswith("|") and cells and re.match(r"^T-\d{2,3}$", cells[0]):
                if len(cells) > 4 and cells[4].upper() in RATE and cells[0] not in ids:
                    ids.append(cells[0])
    return files, ids


TAGS_QA = ("assumption", "untestable", "undefined", "contradiction", "risk")
CLAIM = re.compile(
    r"every (acceptance criterion|criterion|AC)\b[^.\n]*\b(has|have|is covered|are covered)",
    re.I,
)


def check_steps(path, live_rows, problems):
    """Every live manual or e2e case has steps; returns the test-steps line."""
    text = read(path)
    header, rows = table(text or "", "Step", r"^TC-\d{4}\.\d+$")
    if not text or header is None or not rows:
        problems.append(f"{path}: no step rows (| Step | Case | Action | Expected |)")
        return f"test-steps: 0 steps read from {path}"
    c = {name: i for i, name in enumerate(header)}
    for n in ("case", "action", "expected"):
        if n not in c:
            problems.append(f"{path}: no '{n}' column")
            return f"test-steps: table header lacks '{n}'"
    cell = lambda r, n: r[c[n]] if c[n] < len(r) else ""
    seen, has = set(), {}
    for r in rows:
        sid, case = r[0], cell(r, "case")
        if sid in seen:
            problems.append(f"{sid}: duplicate step id")
        seen.add(sid)
        if sid.split(".")[0] != case:
            problems.append(f"{sid}: Case column '{case}' does not match the step id")
        if case not in live_rows:
            problems.append(f"{sid}: {case} is not a live case")
            continue
        has[case] = has.get(case, 0) + 1
        for n in ("action", "expected"):
            v = cell(r, n)
            if not v or VAGUE.match(v):
                problems.append(f"{sid}: {n.title()} '{v}' is not a specific step")
    need = [tc for tc, (_, ty) in live_rows.items() if ty in ("manual", "e2e")]
    for tc in need:
        if tc not in has:
            problems.append(f"{tc}: {live_rows[tc][1]} case has no steps in {path}")
    return (
        f"test-steps: {len(need)} manual or e2e cases, "
        f"{sum(1 for tc in need if tc in has)} with steps, {len(seen)} steps"
    )


def check_plan(path, core, types_line, in_scope, live_rows, gaps, problems):
    """The plan quotes the gate and accounts for every story and case."""
    text = read(path)
    if not text or not text.strip():
        problems.append(f"no test plan at {path}")
        return f"test-plan: no file at {path}"
    body = re.sub(r"<!--.*?-->", "", text, flags=re.S)
    n0 = len(problems)
    # The counts must match this run; the trailing problem count may not,
    # since the plan's own problems are counted after it was written.
    counts = core.rsplit(", ", 1)[0]
    if not re.search(re.escape(counts) + r", \d+ problems", body):
        problems.append(f"{path}: does not quote this run's test-cases line verbatim")
    if types_line not in body:
        problems.append(f"{path}: does not quote this run's test-types line verbatim")
    for h in ("Entry criteria", "Exit criteria", "Environments", "What QA raised"):
        if not re.search(r"^#{2,3}\s+(\d+\.\s*)?" + h, body, re.M | re.I):
            problems.append(f"{path}: no '{h}' section")
    header, rows = table(body, "Scenario", r"^TS-US-(?:\d{2}-\d{3}|LOCAL-\d{3})-\d+$")
    c = {name: i for i, name in enumerate(header or [])}
    if not rows or "proves that" not in c or "cases" not in c:
        problems.append(f"{path}: no scenario rows with Proves that and Cases columns")
        rows = []
    stories_seen, cases_seen, ids = set(), set(), set()
    for r in rows:
        ts = r[0]
        if ts in ids:
            problems.append(f"{ts}: duplicate scenario id")
        ids.add(ts)
        stories_seen.update(STORY_RE.findall(ts))
        proves = r[c["proves that"]] if c["proves that"] < len(r) else ""
        if not proves or VAGUE.match(proves):
            problems.append(f"{ts}: Proves that is blank or vague")
        tcs = re.findall(r"\bTC-\d{4}\b", r[c["cases"]] if c["cases"] < len(r) else "")
        if not tcs:
            problems.append(f"{ts}: names no case")
        for tc in tcs:
            if tc in live_rows:
                cases_seen.add(tc)
            else:
                problems.append(f"{ts}: {tc} is not a live case")
    for st in in_scope:
        if st not in stories_seen:
            problems.append(f"{st}: no scenario in {path}")
    for tc in live_rows:
        if tc not in cases_seen:
            problems.append(f"{tc}: in no scenario of {path}")
    m = re.search(r"Scenarios:\s*(\d+)", body)
    if not m or int(m.group(1)) != len(ids):
        problems.append(
            f"{path}: 'Scenarios: {m.group(1) if m else 'missing'}' does not match {len(ids)} scenario rows"
        )
    qa = re.search(r"^#{2,3}\s+(?:\d+\.\s*)?What QA raised.*?$(.*?)(?=^#{1,3} |\Z)", body, re.M | re.S | re.I)
    concerns = 0
    for line in (qa.group(1) if qa else "").split("\n"):
        if not line.startswith("- "):
            continue
        t = re.match(r"^-\s+\**\[(\w+)\]", line)
        if not t or t.group(1).lower() not in TAGS_QA:
            problems.append(
                f"{path}: concern not tagged [{'], ['.join(TAGS_QA)}]: '{line[2:50]}'"
            )
        else:
            concerns += 1
    if gaps and CLAIM.search(body):
        problems.append(
            f"{path}: claims every criterion has a case while {len(gaps)} have none"
        )
    return (
        f"test-plan: {len(ids)} scenarios over {len(stories_seen)} stories, "
        f"{len(cases_seen)} of {len(live_rows)} live cases placed, {concerns} concerns raised, "
        f"{len(problems) - n0} problems"
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--backlog", default="docs/product/backlog.md")
    ap.add_argument("--cases", default="docs/testing/test-cases.md")
    ap.add_argument("--risks", default="docs/testing/risks.md")
    ap.add_argument("--threats", default="docs/security/threat-model-*.md")
    ap.add_argument("--story", default="")
    ap.add_argument("--steps", default="")
    ap.add_argument("--plan", default="")
    a = ap.parse_args()

    backlog, cases = read(a.backlog), read(a.cases)
    if backlog is None or cases is None:
        missing = a.backlog if backlog is None else a.cases
        print(f"test-cases: no file at {missing}, nothing checked", file=sys.stderr)
        return 1
    acs = criteria(backlog, a.story)
    header, rows = table(cases)
    if not acs:
        print(
            f"test-cases: 0 acceptance criteria in {a.backlog}, nothing checked",
            file=sys.stderr,
        )
        return 1
    if not rows or header is None:
        print(f"test-cases: 0 TC rows in {a.cases}, nothing checked", file=sys.stderr)
        return 1

    col = {name: i for i, name in enumerate(header)}
    need = ["acs", "priority", "automation", "oracles"]
    problems = [f"{a.cases}: no '{n}' column" for n in need if n not in col]
    if problems:
        for p in problems:
            print(f"problem: {p}")
        print(
            f"test-cases: table header lacks {len(problems)} columns, nothing checked",
            file=sys.stderr,
        )
        return 1

    seen, covered, live, oracle_rows = set(), {}, 0, 0
    for r in rows:
        tc = r[0]
        if tc in seen:
            problems.append(f"{tc}: duplicate id")
        seen.add(tc)
        cell = lambda n: r[col[n]] if col[n] < len(r) else ""
        if cell("automation").lower().startswith("retired"):
            continue
        live += 1
        for ac in AC_RE.findall(cell("acs")):
            covered.setdefault(ac, []).append(tc)
        checks = [c.strip() for c in split_checks(cell("oracles")) if c.strip()]
        cats, bad = set(), []
        for c in checks:
            m = re.match(r"^(\w+):\s*(.*)$", c)
            if not m or m.group(1).lower() not in TAGS:
                bad.append(c)
                continue
            if not m.group(2).strip() or VAGUE.match(m.group(2)):
                bad.append(c)
                continue
            cats.add(m.group(1).lower())
        if not cats:
            problems.append(
                f"{tc}: no oracle (tag each check ui:, data:, not:, effect: or inv:)"
            )
            continue
        oracle_rows += 1
        for b in bad:
            problems.append(f"{tc}: '{b[:60]}' is not a tagged, specific check")
        if cell("priority").upper() == "P1" and (len(cats) < 2 or "not" not in cats):
            problems.append(
                f"{tc}: P1 needs two oracle categories including not: (has {', '.join(sorted(cats))})"
            )

    gaps = [ac for ac in acs if ac not in covered]
    for ac in gaps:
        problems.append(f"{ac}: no live case")

    risk_text = read(a.risks)
    if risk_text is None:
        for p in problems:
            print(f"problem: {p}")
        print(f"test-cases: no risk register at {a.risks}, risks not checked", file=sys.stderr)
        return 1
    rhead, rrows = table(risk_text, "Risk", r"^R-\d{3}$")
    rcol = {name: i for i, name in enumerate(rhead or [])}
    rneed = ["story", "source", "likelihood", "impact", "level", "cases"]
    missing = [n for n in rneed if n not in rcol]
    if not rrows or missing:
        for p in problems:
            print(f"problem: {p}")
        why = "0 R-nnn rows" if not rrows else f"no '{missing[0]}' column"
        print(f"test-cases: {why} in {a.risks}, risks not checked", file=sys.stderr)
        return 1

    live_rows = {}
    for r in rows:
        cell = lambda n: r[col[n]] if n in col and col[n] < len(r) else ""
        if not cell("automation").lower().startswith("retired"):
            live_rows[r[0]] = (cell("oracles").lower(), cell("type").lower())

    in_scope = stories(backlog, a.story)
    risk_stories, sources, levels, rseen = set(), set(), {"high": 0, "medium": 0, "low": 0}, set()
    for r in rrows:
        rid = r[0]
        cell = lambda n: r[rcol[n]] if rcol[n] < len(r) else ""
        story_ids = STORY_RE.findall(cell("story"))
        if a.story and a.story not in story_ids:
            continue
        if rid in rseen:
            problems.append(f"{rid}: duplicate id")
        rseen.add(rid)
        risk_stories.update(story_ids)
        sources.update(THREAT_RE.findall(cell("source")))
        li, im, lv = cell("likelihood").upper(), cell("impact").upper(), cell("level").lower()
        if li not in RATE or im not in RATE:
            problems.append(f"{rid}: likelihood and impact must each be L, M or H (has '{li}', '{im}')")
            continue
        want = level(li, im)
        if lv != want:
            problems.append(f"{rid}: level is {want.title()} for likelihood {li} and impact {im}, not '{cell('level')}'")
        levels[want] += 1
        tcs = re.findall(r"\bTC-\d{4}\b", cell("cases"))
        dead = [tc for tc in tcs if tc not in live_rows]
        for tc in dead:
            problems.append(f"{rid}: {tc} is not a live case")
        alive = [live_rows[tc] for tc in tcs if tc in live_rows]
        if len(alive) < DEPTH[want]:
            problems.append(f"{rid}: {want.title()} needs {DEPTH[want]} live cases, has {len(alive)}")
        if want in ("high", "medium") and not any("not:" in o for o, _ in alive):
            problems.append(f"{rid}: {want.title()} needs a case with a not: oracle")
        if want == "high" and not any(ty in ("integration", "e2e") for _, ty in alive):
            problems.append(f"{rid}: High needs an integration or e2e case")
    for s in in_scope:
        if s not in risk_stories:
            problems.append(f"{s}: no risk in {a.risks} (a story with nothing to fear gets one Low row)")
    tfiles, tids = threats(a.threats) if not a.story else ([], [])
    for tid in tids:
        if tid not in sources:
            problems.append(f"{tid}: threat is the source of no risk")

    types = {"unit": 0, "integration": 0, "e2e": 0, "manual": 0}
    auto = {"automated": 0, "planned": 0}
    by_hand = 0
    how_of = {
        r[0]: (r[col["automation"]] if col["automation"] < len(r) else "").lower()
        for r in rows
    }
    for tc, (_, ty) in live_rows.items():
        if ty in types:
            types[ty] += 1
        how = how_of.get(tc, "")
        if ty == "manual" or how.startswith("manual"):
            by_hand += 1
        elif how.startswith("automated"):
            auto["automated"] += 1
        else:
            auto["planned"] += 1
    types_line = (
        f"test-types: unit {types['unit']}, integration {types['integration']}, "
        f"e2e {types['e2e']}, manual {types['manual']}; by machine "
        f"{auto['automated'] + auto['planned']} (automated {auto['automated']}, "
        f"planned {auto['planned']}), by hand {by_hand}"
    )
    extra = [types_line]
    if a.steps:
        extra.append(check_steps(a.steps, live_rows, problems))
    line = lambda n: (
        f"test-cases: {len(acs)} ACs, {len(acs) - len(gaps)} with cases, {live} live cases, "
        f"{oracle_rows} with oracles, {len(rseen)} risks (high {levels['high']}, medium "
        f"{levels['medium']}, low {levels['low']}), {len(tids)} threats traced from "
        f"{len(tfiles)} threat models, {n} problems"
    )
    core = line(len(problems))
    if a.plan:
        extra.append(
            check_plan(a.plan, core, types_line, in_scope, live_rows, gaps, problems)
        )
    for p in problems:
        print(f"problem: {p}")
    for e in extra:
        print(e)
    print(line(len(problems)))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
