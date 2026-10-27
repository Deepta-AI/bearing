#!/usr/bin/env python3
"""trigger-rotation: the skills trigger-eval runs this week.

All 547 trigger cases in one run used up the plan's session limit on 22 Oct
2026, so the weekly run takes:

  changed   every skill whose folder changed since the scoreboard row that
            last measured its triggers (or whose history git cannot read)
  quarter   a rotating quarter of all skills, by ISO week number, so every
            skill is measured at least once in four weeks; a skill never
            measured joins in its quarter, not all at once

Usage: trigger-rotation.py [--board F] [--cases F] [--week N] [--quarters N] [--list]
Prints the names comma-separated for `trigger-eval.py --only`, or with --list
one per line with the reason and "trigger-rotation: N skills (C changed, Q
quarter K of 4)"; exits 1 when it chose no skill.
"""

import argparse
import datetime
import json
import os
import subprocess
import sys

KIT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(KIT, "bin"))
import kit_paths  # noqa: E402

BOARD = os.path.join(KIT, "evals", "scoreboard.jsonl")
CASES = os.path.join(KIT, "evals", "triggers.json")


def last_measured(board):
    """skill -> the commit of the newest row that measured its triggers."""
    out = {}
    if os.path.isfile(board):
        with open(board) as f:
            for line in f:
                if line.strip():
                    row = json.loads(line)
                    for s in (row.get("trigger") or {}).get("skills") or {}:
                        out[s] = row.get("commit") or ""
    return out


def changed(skill, commit):
    d = kit_paths.skill_dir(skill)
    if d is None:
        return None
    p = subprocess.run(
        [
            "git",
            "-C",
            KIT,
            "log",
            "--format=%h",
            f"{commit}..HEAD",
            "--",
            os.path.relpath(str(d), KIT),
        ],
        capture_output=True,
        text=True,
    )
    if p.returncode != 0:
        return f"history unreadable from {commit[:7] or 'unknown'}"
    return f"changed since {commit[:7]}" if p.stdout.strip() else None


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--board", default=BOARD)
    ap.add_argument("--cases", default=CASES)
    ap.add_argument("--week", type=int, default=datetime.date.today().isocalendar()[1])
    ap.add_argument("--quarters", type=int, default=4)
    ap.add_argument("--list", action="store_true")
    a = ap.parse_args()

    skills = sorted({c["skill"] for c in json.load(open(a.cases))})
    if not skills:
        print(
            f"trigger-rotation: 0 skills in {a.cases}; nothing chosen", file=sys.stderr
        )
        return 1
    k = a.week % max(1, a.quarters)
    quarter = {s for i, s in enumerate(skills) if i % a.quarters == k}
    seen = last_measured(a.board)
    why = {}
    for s in skills:
        if s in seen:
            r = changed(s, seen[s])
            if r:
                why[s] = r
    for s in quarter:
        why.setdefault(s, f"quarter {k} of {a.quarters}")
    chosen = sorted(why)
    if a.list:
        for s in chosen:
            print(f"{s} ({why[s]})")
        n_changed = sum(1 for s in chosen if not why[s].startswith("quarter"))
        print(
            f"trigger-rotation: {len(chosen)} skills ({n_changed} changed, "
            f"{len(chosen) - n_changed} quarter {k} of {a.quarters})"
        )
    else:
        print(",".join(chosen))
    return 0 if chosen else 1


if __name__ == "__main__":
    sys.exit(main())
