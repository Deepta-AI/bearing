#!/usr/bin/env python3
"""gallery_check: screens as code hold every state their inventory lists.

The gate for the default react-shadcn stack, where a screen design is a
React module, not an HTML page: src/features/<feature>/screens/<id>-<name>.screen.tsx
exporting `screen: ScreenSpec` with a `states` map (see src/design/screen.ts
in the react-web template). The design gallery at /__design renders each
state with fixtures inside the real layout.

The inventory is section 2 of the flows file, parsed by states_check.py in
this folder (a row whose second cell starts with "n/a" is out of scope). A
state with several rows (three error rows, one per rejection) needs as many
states: the state's own key or keys that start with it (error-rate-limited).
Each inventory screen needs its screen file with every state as a key of
`states`; a screen file whose id is not in the inventory is a problem, and
so is a raw <table>, <button>, <input>, <select>, <textarea> or <dialog>
in a screen file: screens compose src/components/ui.

Usage: gallery_check.py --src <app src dir> --flows <flows.md>... [--only S-10,S-12]
Several flows files (one per feature) merge into one inventory.
Prints one line per problem and the counts; exits 1 on any problem, or when
zero screen files were found.
"""

import argparse
import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from states_check import inventory, row_counts  # noqa: E402

RAW = ("table", "button", "input", "select", "textarea", "dialog")


def screen_files(src):
    return sorted(
        glob.glob(os.path.join(src, "features", "*", "screens", "*.screen.tsx"))
    )


def states_of(text):
    """The keys of the object after `states:`, at its top level."""
    m = re.search(r"\bstates\s*:\s*\{", text)
    if not m:
        return []
    i, depth, start = m.end(), 1, m.end()
    while i < len(text) and depth:
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
        i += 1
    body = text[start : i - 1]
    keys, depth, line_start = [], 0, 0
    for j, ch in enumerate(body):
        if ch in "{([":
            depth += 1
        elif ch in "})]":
            depth -= 1
        elif ch == "\n":
            line_start = j + 1
        if depth == 0 and ch == ":" and body[line_start:j].strip():
            k = body[line_start:j].strip().strip(",").strip()
            k = k.strip("\"'` ")
            if re.fullmatch(r"[A-Za-z][\w-]*", k):
                keys.append(k.lower())
    return keys


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--flows", required=True, nargs="+")
    ap.add_argument("--only", default="")
    a = ap.parse_args()

    files = screen_files(a.src)
    if not files:
        print(
            f"screen-gallery: 0 screen files under {a.src} (src/features/*/screens/*.screen.tsx), nothing checked"
        )
        return 1
    inv, rows = {}, {}
    for fl in a.flows:
        if os.path.isfile(fl):
            inv.update(inventory(fl))
            rows.update(row_counts(fl))
    source = a.flows[0] if len(a.flows) == 1 else f"{len(a.flows)} flows files"
    only = [s.strip() for s in a.only.split(",") if s.strip()]
    if only:
        inv = {k: v for k, v in inv.items() if k in only}
    if not inv:
        print(
            f"screen-gallery: 0 screens in the inventory ({source}), nothing checked"
        )
        return 1

    problems, by_id, states_total, complete = [], {}, 0, 0
    for f in files:
        text = open(f, encoding="utf-8").read()
        m = re.search(r'\bid\s*:\s*["\'](S-\d{2,3})["\']', text)
        name = os.path.basename(f)
        if not m:
            problems.append(f'{name}: no id: "S-nn" in the screen spec')
            continue
        sid = m.group(1)
        by_id[sid] = (name, text)
        if sid not in inv and not only:
            problems.append(f"{sid} ({name}): not in the inventory")
        raw = [t for t in RAW if re.search(rf"<{t}[\s>/]", text)]
        if raw:
            problems.append(
                f"{sid} ({name}): raw {', '.join('<' + t + '>' for t in raw)}; use src/components/ui"
            )

    for sid, want in inv.items():
        if sid not in by_id:
            problems.append(f"{sid}: no src/features/*/screens/{sid}-*.screen.tsx")
            continue
        name, text = by_id[sid]
        have = states_of(text)
        states_total += len(have)
        missing = [s for s in want if s not in have]
        for s in missing:
            problems.append(f"{sid} ({name}): no state {s}")
        # several rows of one state (three error rows, one per rejection)
        # need as many states: the state itself or <state>-<something>
        for s, n in rows.get(sid, {}).items():
            # a key that is itself a labelled row (error-not-found) is that
            # row's state, not one of the bare rows
            got = [k for k in have if k == s or (k.startswith(s + "-") and k not in want)]
            if n > 1 and len(got) < n:
                missing.append(s)
                problems.append(
                    f"{sid} ({name}): {n} {s} rows in the flows, {len(got)} {s} states "
                    f"({', '.join(got) or 'none'}); name each, such as {s}-rate-limited"
                )
        if not missing:
            complete += 1

    for p in problems:
        print(f"problem: {p}")
    print(
        f"screen-gallery: {len(inv)} screens from {source}, {states_total} states, "
        f"{complete} of {len(inv)} screens with all inventory states, {len(problems)} problems"
    )
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
