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

Usage: flows_check.py [--file F ...] [--root docs/design/flows]
Prints one "problem:" line per failure, the Dead ends line and the counts;
exits 1 on any problem, or when zero files or zero screens were read.
"""

import argparse
import glob
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


def check(path):
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
        "tables": len(table),
        "missing": missing,
        "problems": problems,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--file", nargs="*", default=None)
    ap.add_argument("--root", default="docs/design/flows")
    a = ap.parse_args()
    files = [f for f in (a.file or pick_files(a.root)) if os.path.isfile(f)]
    if not files:
        print(
            f"ux-flows: 0 flow files read ({a.file or a.root}), nothing checked",
            file=sys.stderr,
        )
        return 1
    tot = {}
    problems = []
    owner = {}
    for f in files:
        # one product's packages share one id space: the design gallery and
        # gallery_check merge them, so an id two features use is ambiguous
        for s_ in inventory_full(read(f))[0]:
            if s_ in owner and owner[s_] != f:
                problems.append(f"{f}: {s_} is also a screen in {owner[s_]}; screen ids continue across packages")
            owner.setdefault(s_, f)
        r = check(f)
        problems += r.pop("problems")
        for k, v in r.items():
            tot[k] = tot.get(k, 0) + v
    if tot["screens"] == 0:
        print(
            f"ux-flows: {len(files)} files, 0 screens in the inventory, nothing checked",
            file=sys.stderr,
        )
        return 1
    for p in problems:
        print(f"problem: {p}")
    print(f"Dead ends: {tot['dead']}")
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
