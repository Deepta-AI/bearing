#!/usr/bin/env python3
"""flows_check: a UX flow package has no dead end, no unflowed screen and no
missing state, computed from the mermaid and the tables in the file.

  - File: --file, else per feature under docs/design/flows/<feature>/ the
    highest flows-v<n>.md, or flows.md when there is no versioned file.
  - Screens: the ids (S-nn, "(modal)" allowed) in the first column of the
    table under the "Screen inventory" (or "Screens") heading. A row whose
    Exits cell says `terminal` is a screen allowed no way forward. A row
    whose Status cell says `removed` or `retired` (a screen dropped in a
    later version, its id kept) is counted as removed and not checked.
  - Edges: every ```mermaid block that starts with `flowchart` or `graph`.
    A node is a screen when its id is S-nn or Snn, or its label starts
    with S-nn. Edges are -->, ---, -.->, ==>, with |labels| or -- text -->,
    chained (A --> B --> C) and grouped (A & B --> C); --- links both
    ways. An edge through a decision node counts as a way forward.
    `%% terminal: S-nn <reason>` in a block also marks a terminal screen.
  - Ids across packages: every package read in one run shares the id
    space (the design gallery merges them); an id in two packages is a
    problem.
  - Dead end: an inventory screen with no outgoing edge that is not
    terminal. Unflowed: an inventory screen in no flowchart. Unknown: a
    screen in a flowchart that is not in the inventory.
  - Dialogs: an inventory row whose Id cell says "(modal)", whose Kind or
    Type column says dialog or modal, or whose Screen cell names a dialog,
    modal or confirmation and not a page or screen ("Newsletter
    confirmation page" is a page). Unless terminal, its Exits cell must
    name a way back (cancel, back, close, dismiss, keep, Escape).
  - States: under "### S-nn" headings, a table whose first column is the
    state (a cell naming several, "Loading, Empty", fills each; a label
    with a qualifier, "error: slot_unavailable" or "error (409)", is that
    state, and a screen may have one such row per rejection). loading,
    empty, error and success are required on every
    screen; a row that reads `n/a` needs a reason (`n/a: <reason>`); a
    required row missing, blank, or n/a without a reason is a problem, and
    so is an inventory screen with no state table.
  - Task paths: the table under "## Task paths" (| Task | Story | Kind |
    Entry | Path | Screens | Interactions | Over |), one row per user task.
    A path is segments split on " > ": `S-nn[ (modal)][: item, item]`, each
    comma item one interaction (a typed field is one item, never one per
    keystroke; the content typed is not counted). The script recounts
    screens (distinct) and interactions from the path and holds them to
    the budget, never trusting the written counts: primary at most 3
    screens and 6 interactions, secondary at most 5 and 10, overridable in
    .bearing/config.json (ux.budget.primary.screens, .interactions, and
    the same for secondary). A row over budget fails unless its Over cell
    reads `over: <reason>`. Also failing: written counts that disagree, a
    kind other than primary or secondary, a path through a screen not in
    the inventory, an entry that is not the path's first screen, a story
    the inventory serves that no task path names, and zero task paths.

Usage: flows_check.py [--file F ...] [--root docs/design/flows]
                      [--config .bearing/config.json]
Prints one "problem:" line per failure, the Dead ends line, the task paths
line and the counts; exits 1 on any problem, or when zero files or zero
screens were read.
"""

import argparse
import glob
import json
import os
import re
import sys

REQUIRED = ["loading", "empty", "error", "success"]
SID = re.compile(r"\bS-?(\d{2,3})\b")
NODE = re.compile(
    r"([A-Za-z0-9_]+(?:-[A-Za-z0-9_]+)*)\s*(\[\[.*?\]\]|\[\(.*?\)\]|\(\(.*?\)\)|\[/.*?/\]|\[.*?\]|\(\[.*?\]\)|\(.*?\)|\{\{.*?\}\}|\{.*?\}|>.*?\])"
)
ARROW = re.compile(r"\s*(<?(?:-{2,}|-\.+-|={2,})(?:>|o|x)?)\s*")
SKIP_LINE = re.compile(
    r"^\s*(flowchart|graph|subgraph|end\b|classDef|class\s|style\s|click\s|linkStyle|direction\s)"
)


def read(p):
    return open(p, encoding="utf-8", errors="replace").read()


def pick_files(root):
    out = []
    for d in sorted(glob.glob(os.path.join(root, "*"))):
        if not os.path.isdir(d):
            continue
        versions = []
        for f in glob.glob(os.path.join(d, "flows-v*.md")):
            m = re.search(r"flows-v(\d+)\.md$", f)
            if m:
                versions.append((int(m.group(1)), f))
        if versions:
            out.append(max(versions)[1])
        elif os.path.isfile(os.path.join(d, "flows.md")):
            out.append(os.path.join(d, "flows.md"))
    return out


def section(text, title):
    m = re.search(
        r"^##\s+(?:\d+\.\s*)?" + title + r".*?$(.*?)(?=^## |\Z)", text, re.M | re.S
    )
    return m.group(1) if m else ""


def sid(raw):
    m = SID.search(raw)
    return f"S-{m.group(1)}" if m else None


DIALOG = re.compile(r"\b(modal|dialog|confirm|confirmation)\b", re.I)
PAGE = re.compile(r"\b(page|screen)\b", re.I)
WAY_BACK = re.compile(r"\b(cancel|back|close|dismiss|keep|escape|esc)\b", re.I)


def inventory(text):
    """(screens, terminal): the shape screen-design's bundle.py imports."""
    screens, terminal, _, _ = inventory_full(text)
    return screens, terminal


def inventory_full(text):
    screens, terminal, dialogs, removed = [], set(), {}, []
    header = None
    for line in section(text, r"Screens?(?: inventory)?[ \t]*$").split("\n"):
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if header is None:
            header = [c.lower() for c in cells]
            continue
        m = re.match(r"^S-(\d{2,3})\b", cells[0])
        if not m:
            continue
        s = f"S-{m.group(1)}"
        st = header.index("status") if "status" in header else None
        if st is not None and st < len(cells) and re.search(r"\b(removed|retired)\b", cells[st], re.I):
            if s not in removed:
                removed.append(s)
            continue
        if s not in screens:
            screens.append(s)
        ex = next((i for i, h in enumerate(header) if h.startswith("exit")), None)
        exits = cells[ex] if ex is not None and ex < len(cells) else ""
        if "terminal" in exits.lower():
            terminal.add(s)
        name = cells[1] if len(cells) > 1 else ""
        kind_i = next((i for i, h in enumerate(header) if h in ("kind", "type")), None)
        kind = cells[kind_i] if kind_i is not None and kind_i < len(cells) else ""
        named = DIALOG.search(name) and not PAGE.search(name)
        if "(modal)" in cells[0].lower() or re.search(r"\b(dialog|modal)\b", kind, re.I) or named:
            dialogs[s] = exits
    return screens, terminal, dialogs, removed


def flowcharts(text):
    blocks = re.findall(r"^```mermaid\s*\n(.*?)^```", text, re.M | re.S)
    return [b for b in blocks if re.match(r"^\s*(flowchart|graph)\b", b)]


def parse_block(block, labels, edges, seen, terminal):
    for line in block.split("\n"):
        t = re.match(r"^\s*%%\s*terminal:\s*(S-\d{2,3})", line)
        if t:
            terminal.add(t.group(1))
            continue
        if not line.strip() or line.strip().startswith("%%") or SKIP_LINE.match(line):
            continue
        for m in NODE.finditer(line):
            labels.setdefault(m.group(1), m.group(2)[1:-1])
        line = NODE.sub(lambda m: m.group(1), line)
        line = re.sub(r"\|[^|]*\|", " ", line)
        line = re.sub(r"--\s+[^->]+?\s+-->", "-->", line)
        line = re.sub(r"-\.\s+[^.]+?\s+\.->", "-.->", line)
        parts = ARROW.split(line.strip())
        # parts: node, arrow, node, arrow, node ...
        groups = [[n.strip() for n in p.split("&") if n.strip()] for p in parts[0::2]]
        arrows = parts[1::2]
        for g in groups:
            for n in g:
                seen.add(n)
        for i, arrow in enumerate(arrows):
            if i + 1 >= len(groups):
                break
            for x in groups[i]:
                for y in groups[i + 1]:
                    edges.add((x, y))
                    if not arrow.endswith((">", "o", "x")):
                        edges.add((y, x))


def screen_of(node, labels):
    if re.match(r"^S-?\d{2,3}$", node):
        return sid(node)
    lab = labels.get(node, "").strip().strip('"')
    m = re.match(r"^S-(\d{2,3})\b", lab)
    return f"S-{m.group(1)}" if m else None


def filled(cell):
    """A state cell that counts: not blank, and an n/a carries its reason."""
    return bool(cell.strip()) and not (re.match(r"^n/?a\b", cell, re.I) and not re.match(r"^n/?a:\s*\S", cell, re.I))


def states(text):
    """{screen: {state: cell text}} from '### S-nn' tables."""
    out, cur = {}, None
    for line in text.split("\n"):
        h = re.match(r"^###\s+(S-\d{2,3})\b", line)
        if h:
            cur = h.group(1)
            out.setdefault(cur, {})
            continue
        if re.match(r"^#{1,6}\s", line):
            cur = None
            continue
        if cur is None or not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        st = cells[0].lower()
        if st in ("state", "") or re.match(r"^:?-+:?$", st):
            continue
        # "Loading, Empty, Partial | n/a: ..." fills each state it names;
        # "error: slot_unavailable" is an error row, one per rejection, and a
        # filled row is never replaced by a blank or reasonless one.
        value = " ".join(cells[1:]).strip()
        for one in re.split(r"\s*(?:,|/|\band\b)\s*", st):
            base = re.split(r"\s*[:(]", one, maxsplit=1)[0].strip()
            if base and not (base in out[cur] and filled(out[cur][base])):
                out[cur][base] = value
    return out

DEFAULT_BUDGET = {"primary": (3, 6), "secondary": (5, 10)}
BUDGET_KEYS = {
    ("primary", 0): "ux.budget.primary.screens",
    ("primary", 1): "ux.budget.primary.interactions",
    ("secondary", 0): "ux.budget.secondary.screens",
    ("secondary", 1): "ux.budget.secondary.interactions",
}
SEGMENT = re.compile(r"^(S-\d{2,3})(?:\s*\(modal\))?\s*(?::(.*))?$", re.I | re.S)
REASON_HINT = "add a ## Task paths section, one row per primary task: ux-flows references/task-paths.md"


def whole(v):
    """A positive whole number, as a number or a string of digits."""
    if isinstance(v, bool):
        return None
    if isinstance(v, int):
        return v if v > 0 else None
    if isinstance(v, str) and re.fullmatch(r"\s*\d+\s*", v):
        return int(v) if int(v) > 0 else None
    return None


def budget(config_path):
    """({"primary": (screens, interactions), "secondary": (...)}, problems)."""
    out = {k: list(v) for k, v in DEFAULT_BUDGET.items()}
    problems = []
    if not os.path.isfile(config_path):
        return {k: tuple(v) for k, v in out.items()}, problems
    try:
        cfg = json.loads(read(config_path))
        if not isinstance(cfg, dict):
            raise ValueError("not an object")
    except ValueError as e:
        problems.append(f"{config_path}: not valid JSON ({e}); the default budget stays")
        return {k: tuple(v) for k, v in out.items()}, problems
    for (kind, i), key in BUDGET_KEYS.items():
        if key not in cfg or cfg[key] is None:
            continue
        n = whole(cfg[key])
        if n is None:
            problems.append(
                f"{config_path}: {key} is {json.dumps(cfg[key])}, not a whole number above 0"
            )
        else:
            out[kind][i] = n
    return {k: tuple(v) for k, v in out.items()}, problems


def count_path(cell):
    """(distinct screens, interactions, screen ids in order) for one path."""
    ids, inter = [], 0
    for seg in re.split(r"\s+>\s+", cell.strip()):
        m = SEGMENT.match(seg.strip())
        if not m:
            continue
        s = m.group(1).upper()
        ids.append(s)
        if m.group(2):
            inter += len([i for i in m.group(2).split(",") if i.strip()])
    return len(set(ids)), inter, ids


def task_paths(text):
    """Rows of the Task paths table as dicts (see the header names)."""
    rows, header = [], None
    for line in section(text, r"Task paths").split("\n"):
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if header is None:
            header = [c.lower() for c in cells]
            continue
        if re.match(r"^:?-+:?$", cells[0]):
            continue

        def col(name):
            return cells[header.index(name)] if name in header and header.index(name) < len(cells) else ""

        over_cell = col("over")
        m = re.match(r"^over:\s*(.*)$", over_cell, re.I | re.S)
        if m:
            over = m.group(1).strip() or None
        else:
            over = ""  # blank; any other text is flagged through over_raw
        rows.append({
            "task": col("task"),
            "story": re.findall(r"US-[A-Za-z0-9-]+", col("story")),
            "kind": col("kind").lower(),
            "entry": col("entry"),
            "path": col("path"),
            "screens": col("screens"),
            "interactions": col("interactions"),
            "over": over,
            "over_raw": over_cell,
        })
    return rows


def served(text):
    """US- ids in the Serves column of the non-removed inventory rows."""
    out, header = [], None
    for line in section(text, r"Screens?(?: inventory)?[ \t]*$").split("\n"):
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if header is None:
            header = [c.lower() for c in cells]
            continue
        if not re.match(r"^S-\d{2,3}\b", cells[0]) or "serves" not in header:
            continue
        st = header.index("status") if "status" in header else None
        if st is not None and st < len(cells) and re.search(r"\b(removed|retired)\b", cells[st], re.I):
            continue
        i = header.index("serves")
        for u in re.findall(r"US-[A-Za-z0-9-]+", cells[i] if i < len(cells) else ""):
            if u not in out:
                out.append(u)
    return out


def check_tasks(path, text, screens, limits):
    """(problems, tasks, over, over_reason) for the Task paths section."""
    problems = []
    rows = task_paths(text)
    if not rows:
        problems.append(f"{path}: 0 task paths ({REASON_HINT})")
        return problems, 0, 0, 0
    over_n = reason_n = 0
    named = set()
    for r in rows:
        t = f'task "{r["task"]}"'
        named.update(r["story"])
        sc, it, ids = count_path(r["path"])
        segs = re.split(r"\s+>\s+", r["path"].strip())
        for n, seg in enumerate(segs):
            m = SEGMENT.match(seg.strip())
            if not m:
                problems.append(f'{path}: {t} path segment "{seg.strip()}" does not start with a screen id (S-nn)')
            elif n < len(segs) - 1 and not [i for i in (m.group(2) or "").split(",") if i.strip()]:
                problems.append(
                    f'{path}: {t} path segment "{seg.strip()}" has no interaction; '
                    "every screen but the last needs the interaction that leaves it (S-nn: tap X)"
                )
        for s in dict.fromkeys(ids):
            if s not in screens:
                problems.append(f"{path}: {t} path names {s}, not in the inventory")
        if ids and r["entry"] and sid(r["entry"]) != ids[0]:
            problems.append(f"{path}: {t} entry {sid(r['entry']) or r['entry']} is not the first screen of its path ({ids[0]})")
        ws, wi = whole(r["screens"]), whole(r["interactions"])
        if r["interactions"].strip() == "0":
            wi = 0
        if ws is None or wi is None:
            problems.append(f"{path}: {t} Screens and Interactions must be whole numbers")
        elif (ws, wi) != (sc, it):
            problems.append(f"{path}: {t} counts written {ws} screens, {wi} interactions; the path has {sc} and {it}")
        if r["kind"] not in limits:
            problems.append(f"{path}: {t} kind must be primary or secondary")
            continue
        ms, mi = limits[r["kind"]]
        if r["over_raw"] and not re.match(r"^over:", r["over_raw"], re.I):
            problems.append(f"{path}: {t} Over cell must be blank or read over: <reason>")
        o = r["over"]
        if o is None:
            problems.append(f"{path}: {t} over: needs a reason")
        if sc <= ms and it <= mi:
            continue
        over_n += 1
        if o is None:
            pass
        elif o == "":
            problems.append(
                f"{path}: {t} is over budget: {sc} screens, {it} interactions "
                f"({r['kind']} budget {ms} and {mi}); shorten it, or write over: <reason> in the Over cell"
            )
        else:
            reason_n += 1
    for u in served(text):
        if u not in named:
            problems.append(f"{path}: story {u} is served by the inventory but has no task path")
    return problems, len(rows), over_n, reason_n


def check(path, limits=None):
    text = read(path)
    problems = []
    screens, terminal, dialogs, removed = inventory_full(text)
    labels, edges, seen = {}, set(), set()
    blocks = flowcharts(text)
    for b in blocks:
        parse_block(b, labels, edges, seen, terminal)
    in_flow, out_edges = set(), {}
    for n in seen:
        s = screen_of(n, labels)
        if s:
            in_flow.add(s)
    for x, y in edges:
        s = screen_of(x, labels)
        if s and x != y:
            out_edges[s] = out_edges.get(s, 0) + 1
    dead = [s for s in screens if s not in terminal and not out_edges.get(s)]
    unflowed = [s for s in screens if s not in in_flow]
    for s in dead:
        problems.append(
            f"{path}: {s} is a dead end (no outgoing edge; mark it terminal in the inventory if it is the end)"
        )
    for s in unflowed:
        problems.append(f"{path}: {s} is in the inventory but in no flowchart")
    for s in sorted(in_flow - set(screens)):
        if s in removed:
            problems.append(f"{path}: {s} is marked removed but still appears in a flowchart")
            continue
        problems.append(
            f"{path}: {s} is in a flowchart but not in the screen inventory"
        )
    no_back = [s for s, ex in dialogs.items() if s not in terminal and not WAY_BACK.search(ex)]
    for s in no_back:
        problems.append(
            f"{path}: {s} is a dialog with no cancel, back or close in its Exits"
        )
    task_problems, tasks, over_n, reason_n = check_tasks(
        path, text, set(screens), limits or {k: v for k, v in DEFAULT_BUDGET.items()}
    )
    problems += task_problems
    table = states(text)
    missing = 0
    for s in screens:
        if s not in table:
            problems.append(f"{path}: {s} has no state table")
            missing += len(REQUIRED)
            continue
        for st in REQUIRED:
            cell = table[s].get(st)
            if cell is None or not cell.strip():
                problems.append(f"{path}: {s} state '{st}' is missing or blank")
                missing += 1
            elif re.match(r"^n/?a\b", cell, re.I) and not re.match(
                r"^n/?a:\s*\S", cell, re.I
            ):
                problems.append(
                    f"{path}: {s} state '{st}' is n/a without a reason (write n/a: <reason>)"
                )
                missing += 1
    return {
        "screens": len(screens),
        "terminal": len(terminal & set(screens)),
        "removed": len(removed),
        "dialogs": len(dialogs),
        "no_back": len(no_back),
        "blocks": len(blocks),
        "edges": len(edges),
        "dead": len(dead),
        "unflowed": len(unflowed),
        "tasks": tasks,
        "over": over_n,
        "over_reason": reason_n,
        "tables": len(table),
        "missing": missing,
        "problems": problems,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--file", nargs="*", default=None)
    ap.add_argument("--root", default="docs/design/flows")
    ap.add_argument("--config", default=".bearing/config.json")
    a = ap.parse_args()
    limits, problems = budget(a.config)
    files = [f for f in (a.file or pick_files(a.root)) if os.path.isfile(f)]
    if not files:
        for p_ in problems:
            print(f"problem: {p_}")
        print(
            f"ux-flows: 0 flow files read ({a.file or a.root}), nothing checked",
            file=sys.stderr,
        )
        return 1
    tot = {}
    owner = {}
    for f in files:
        # one product's packages share one id space: the design gallery and
        # gallery_check merge them, so an id two features use is ambiguous
        for s_ in inventory_full(read(f))[0]:
            if s_ in owner and owner[s_] != f:
                problems.append(f"{f}: {s_} is also a screen in {owner[s_]}; screen ids continue across packages")
            owner.setdefault(s_, f)
        r = check(f, limits)
        problems += r.pop("problems")
        for k, v in r.items():
            tot[k] = tot.get(k, 0) + v
    if tot["screens"] == 0:
        for p_ in problems:
            print(f"problem: {p_}")
        print(
            f"ux-flows: {len(files)} files, 0 screens in the inventory, nothing checked",
            file=sys.stderr,
        )
        return 1
    for p in problems:
        print(f"problem: {p}")
    print(f"Dead ends: {tot['dead']}")
    print(f"task paths: {tot['tasks']} tasks, {tot['over']} over budget ({tot['over_reason']} with reason)")
    print(
        f"ux-flows: {len(files)} files, {tot['screens']} screens ({tot['terminal']} terminal, {tot['removed']} removed), "
        f"{tot['dialogs']} dialogs ({tot['no_back']} without a way back), "
        f"{tot['blocks']} flowcharts, {tot['edges']} edges, {tot['dead']} dead ends, "
        f"{tot['unflowed']} unflowed, {tot['tables']} state tables, {tot['missing']} missing states, "
        f"{len(problems)} problems"
    )
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
