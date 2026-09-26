#!/usr/bin/env python3
"""lint-skill-evals: every skill carries skill-creator evals, or is on the
pending list, and the pending list only shrinks.

A skill's evals live at evals/<name>/evals.json, outside the skill folder so
a run that follows the skill never reads its grading, in skill-creator's
case schema: {"skill_name": <name>, "evals": [{"id": int, "prompt": str,
"expected_output": str, "files": [paths], "expectations": [str, ...]}]}.
The cases are written and run with skill-creator (with the skill against a
baseline without it, graded, benchmarked); this lint checks they exist and
are well formed, not how they scored.

evals/.pending lists the skills that predate this rule, one name per
line. A skill with no evals that is not listed fails (new skills need
evals); a listed skill that now has evals fails too, so its row is removed
and the list ratchets down.

Usage: lint-skill-evals.py [skills-dir] [evals-dir] [pending-file]
An evals/<name> folder with no matching skill is a problem too.
Prints one line per problem and the counts; exits 1 on any problem, or when
zero skills were examined.
"""

import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def check_evals(name, eval_dir, path, problems):
    try:
        data = json.load(open(path, encoding="utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError) as e:
        problems.append(f"{name}: evals.json is not JSON ({e})")
        return 0
    if data.get("skill_name") != name:
        problems.append(
            f"{name}: evals.json skill_name is {data.get('skill_name')!r}, not {name!r}"
        )
    cases = data.get("evals")
    if not isinstance(cases, list) or not cases:
        problems.append(f"{name}: evals.json has no cases")
        return 0
    ids = set()
    for i, c in enumerate(cases):
        where = f"{name}: case {c.get('id', i)}"
        if not isinstance(c.get("id"), int):
            problems.append(f"{where}: id is not an integer")
        elif c["id"] in ids:
            problems.append(f"{where}: duplicate id")
        else:
            ids.add(c["id"])
        for key in ("prompt", "expected_output"):
            if not isinstance(c.get(key), str) or not c[key].strip():
                problems.append(f"{where}: no {key}")
        exp = c.get("expectations")
        if not isinstance(exp, list) or not [
            e for e in exp if isinstance(e, str) and e.strip()
        ]:
            problems.append(
                f"{where}: no expectations (the verifiable statements a grader checks)"
            )
        for f in c.get("files") or []:
            if not os.path.exists(os.path.join(eval_dir, f)):
                problems.append(f"{where}: input file {f} does not exist")
    return len(cases)


def main():
    skills_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "skills")
    evals_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "evals")
    pending_file = (
        sys.argv[3] if len(sys.argv) > 3 else os.path.join(evals_dir, ".pending")
    )
    if not os.path.isdir(skills_dir):
        print(
            f"lint-evals: no skills directory at {skills_dir}, nothing checked",
            file=sys.stderr,
        )
        return 1
    pending = set()
    if os.path.exists(pending_file):
        pending = {
            l.strip()
            for l in open(pending_file, encoding="utf-8")
            if l.strip() and not l.startswith("#")
        }
    names = sorted(
        d
        for d in os.listdir(skills_dir)
        if os.path.isfile(os.path.join(skills_dir, d, "SKILL.md"))
    )
    problems, with_evals, cases = [], 0, 0
    for name in names:
        d = os.path.join(evals_dir, name)
        path = os.path.join(d, "evals.json")
        if os.path.isdir(os.path.join(skills_dir, name, "evals")):
            problems.append(
                f"{name}: skills/{name}/evals/ exists; evals live in evals/{name}/, away from the skill"
            )
        if os.path.isfile(path):
            with_evals += 1
            cases += check_evals(name, d, path, problems)
            if name in pending:
                problems.append(f"{name}: has evals now; remove it from evals/.pending")
        elif name not in pending:
            problems.append(
                f"{name}: no evals/{name}/evals.json (write and run them with skill-creator; new-skill step 7)"
            )
    for name in sorted(pending - set(names)):
        problems.append(f"evals/.pending: {name} is not a skill")
    if os.path.isdir(evals_dir):
        for name in sorted(os.listdir(evals_dir)):
            if os.path.isdir(os.path.join(evals_dir, name)) and name not in names:
                problems.append(f"evals/{name}: no skill of that name")
    for p in problems:
        print(f"problem: {p}")
    if not names:
        print("lint-evals: 0 skills, nothing checked", file=sys.stderr)
        return 1
    print(
        f"lint-evals: {len(names)} skills, {with_evals} with evals ({cases} cases), "
        f"{len(pending & set(names))} pending, {len(problems)} problems"
    )
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
