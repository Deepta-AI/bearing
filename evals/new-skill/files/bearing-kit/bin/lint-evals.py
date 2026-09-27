#!/usr/bin/env python3
"""lint-evals: every skill has evals/<name>/evals.json or sits on evals/.pending."""

import json
import os
import sys

from skills import ROOT, skills


def main():
    found = skills()
    if not found:
        print("lint-evals: 0 skills, nothing checked", file=sys.stderr)
        return 1
    names = {name for _, name, _ in found}
    pending_path = os.path.join(ROOT, "evals", ".pending")
    pending = set()
    if os.path.exists(pending_path):
        with open(pending_path, encoding="utf-8") as f:
            pending = {l.strip() for l in f if l.strip() and not l.startswith("#")}
    problems, cases = [], 0
    for name in sorted(names):
        path = os.path.join(ROOT, "evals", name, "evals.json")
        if not os.path.exists(path):
            if name not in pending:
                problems.append(f"{name}: no evals/{name}/evals.json")
            continue
        if name in pending:
            problems.append(f"{name}: has evals; remove it from evals/.pending")
        try:
            data = json.load(open(path, encoding="utf-8"))
        except json.JSONDecodeError as e:
            problems.append(f"{name}: evals.json is not JSON ({e})")
            continue
        if data.get("skill_name") != name:
            problems.append(f"{name}: skill_name is {data.get('skill_name')!r}")
        for c in data.get("evals") or []:
            cases += 1
            if not c.get("prompt") or not c.get("expectations"):
                problems.append(f"{name}: case {c.get('id')} needs a prompt and expectations")
            for f in c.get("files") or []:
                if not os.path.exists(os.path.join(ROOT, "evals", name, f)):
                    problems.append(f"{name}: case {c.get('id')} file {f} does not exist")
        if not data.get("evals"):
            problems.append(f"{name}: evals.json has no cases")
    for name in sorted(pending - names):
        problems.append(f"evals/.pending: {name} is not a skill")
    for p in problems:
        print(f"problem: {p}")
    print(f"lint-evals: {len(names)} skills, {cases} cases, {len(pending & names)} pending, {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
