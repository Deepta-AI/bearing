#!/usr/bin/env python3
"""states_check: every screen prototype renders every state its inventory lists.

The inventory is section 2 ("Interaction states") of the flows file: one
"### S-nn <name>" heading per screen and a table of states under it; a row
whose second cell starts with "n/a" is out of scope. With no flows file,
each screen must render the five baseline states (loading, empty, error,
success, partial) unless the page carries <!-- n/a: <state> because ... -->.

A screen's prototype is <screens dir>/<id>-<name>.html (S-01-orders.html).
Its states are the values of data-state="..." on its panels; each panel also
needs a control that reaches it (data-state-target="...", a repo's own
data-target="...", or an href="#state=..." link), and the file must hold no
unfilled {{PLACEHOLDER}}. State names compare case-blind with spaces and
underscores read as hyphens, so the flows' "no slots" is the page's
"no-slots": a repository's existing mockups are checked as they are, never
rewritten to suit this gate.

Usage: states_check.py --screens <dir> [--flows <flows.md>] [--only S-01,S-03]
Prints one line per problem and the counts; exits 1 on any problem, or when
zero screens were checked.
"""

import argparse
import glob
import os
import re
import sys

BASELINE = ["loading", "empty", "error", "success", "partial"]


def norm(state):
    """One spelling per state: lower case; spaces, underscores, colons and
    brackets as hyphens ("error: slot_unavailable" is error-slot-unavailable,
    "error (409)" is error-409)."""
    return re.sub(r"[\s_:()]+", "-", state.strip().lower()).strip("-")


def row_counts(flows_path):
    """{screen id: {state: rows}}: how many rows of section 2 carry each
    state, so a screen with three bare "error" rows is known to need three
    error states, not one."""
    text = open(flows_path, encoding="utf-8").read()
    m = re.search(r"^## 2\. .*?$(.*?)(?=^## \d+\. |\Z)", text, re.M | re.S)
    out, cur = {}, None
    for line in (m.group(1) if m else "").split("\n"):
        h = re.match(r"^###\s+(S-\d{2,3})\b", line)
        if h:
            cur = h.group(1)
            out[cur] = {}
            continue
        if cur is None or not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 2 or cells[0].lower() in ("state", "") or set(cells[0]) <= set("-: "):
            continue
        if cells[1].lower().startswith("n/a"):
            continue
        state = norm(re.sub(r"[`*]", "", cells[0]))
        if state:
            out[cur][state] = out[cur].get(state, 0) + 1
    return out


def inventory(flows_path):
    """{screen id: [states]} from section 2 of the flows file."""
    text = open(flows_path, encoding="utf-8").read()
    m = re.search(r"^## 2\. .*?$(.*?)(?=^## \d+\. |\Z)", text, re.M | re.S)
    if not m:
        return {}
    screens, cur = {}, None
    for line in m.group(1).split("\n"):
        h = re.match(r"^###\s+(S-\d{2,3})\b", line)
        if h:
            cur = h.group(1)
            screens[cur] = []
            continue
        if cur is None or not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if (
            len(cells) < 2
            or cells[0].lower() in ("state", "")
            or set(cells[0]) <= set("-: ")
        ):
            continue
        if cells[1].lower().startswith("n/a"):
            continue
        state = norm(re.sub(r"[`*]", "", cells[0]))
        if state and state not in screens[cur]:
            screens[cur].append(state)
    return screens


def screen_file(screens_dir, sid):
    for pat in (
        f"{sid}-*.html",
        f"{sid.lower()}-*.html",
        f"{sid.replace('-', '')}*.html",
    ):
        hits = sorted(glob.glob(os.path.join(screens_dir, pat)))
        if hits:
            return hits[0]
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--screens", required=True)
    ap.add_argument("--flows")
    ap.add_argument("--only", default="")
    a = ap.parse_args()

    only = [s.strip() for s in a.only.split(",") if s.strip()]
    if a.flows and os.path.isfile(a.flows):
        inv = inventory(a.flows)
        source = a.flows
    else:
        files = sorted(glob.glob(os.path.join(a.screens, "S-*.html")))
        inv = {
            re.match(r"(S-\d{2,3})", os.path.basename(f)).group(1): None
            for f in files
            if re.match(r"S-\d{2,3}", os.path.basename(f))
        }
        source = "baseline five (no flows file)"
    if only:
        inv = {k: v for k, v in inv.items() if k in only}
    if not inv:
        print(
            f"screen-states: 0 screens in the inventory ({source}), nothing checked",
            file=sys.stderr,
        )
        return 1

    problems, panels_total, complete = [], 0, 0
    for sid, want in inv.items():
        path = screen_file(a.screens, sid)
        if not path:
            problems.append(f"{sid}: no prototype in {a.screens}")
            continue
        html = open(path, encoding="utf-8").read()
        name = os.path.basename(path)
        panels = re.findall(r'\bdata-state="([^"]+)"', html)
        targets = set(
            norm(t)
            for t in re.findall(r'\bdata-(?:state-)?target="([^"]+)"', html)
            + re.findall(r'href="#state=([^"&]+)"', html)
        )
        panels_total += len(panels)
        if want is None:
            exempt = set(
                s.lower() for s in re.findall(r"<!--\s*n/a:\s*([a-z-]+)\b", html, re.I)
            )
            want = [s for s in BASELINE if s not in exempt]
        have = set(norm(p) for p in panels)
        missing = [s for s in want if s not in have]
        for s in missing:
            problems.append(f'{sid} ({name}): no data-state="{s}" panel')
        for p in panels:
            if norm(p) not in targets:
                problems.append(
                    f"{sid} ({name}): panel {p} has no state-bar button (data-state-target)"
                )
        holes = sorted(set(re.findall(r"\{\{[A-Z_#/]+\}\}", html)))
        if holes:
            problems.append(
                f"{sid} ({name}): unfilled placeholders {', '.join(holes[:5])}"
            )
        if not missing:
            complete += 1

    for p in problems:
        print(f"problem: {p}")
    print(
        f"screen-states: {len(inv)} screens from {source}, {panels_total} state panels, "
        f"{complete} of {len(inv)} screens with all inventory states, {len(problems)} problems"
    )
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
