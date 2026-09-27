#!/usr/bin/env python3
"""lint-triggers: every skill not on evals/.pending has 3 trigger requests and 2 near misses."""

import json
import os
import sys

from skills import ROOT, skills


def main():
    found = skills()
    if not found:
        print("lint-triggers: 0 skills, nothing checked", file=sys.stderr)
        return 1
    names = {name for _, name, _ in found}
    with open(os.path.join(ROOT, "evals", ".pending"), encoding="utf-8") as f:
        pending = {l.strip() for l in f if l.strip() and not l.startswith("#")}
    entries = {e.get("skill"): e for e in json.load(open(os.path.join(ROOT, "evals", "triggers.json")))}
    problems, checked = [], 0
    for name in sorted(names - pending):
        checked += 1
        e = entries.get(name)
        if not e:
            problems.append(f"{name}: no entry in evals/triggers.json")
            continue
        if len(e.get("should") or []) < 3:
            problems.append(f"{name}: needs 3 should-trigger requests")
        near = e.get("near") or []
        if len(near) < 2 or any(n.get("expect") not in names for n in near):
            problems.append(f"{name}: needs 2 near misses whose expect names an existing skill")
    for name in sorted(set(entries) - names):
        problems.append(f"evals/triggers.json: {name} is not a skill")
    for p in problems:
        print(f"problem: {p}")
    print(f"lint-triggers: {checked} skills checked, {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
