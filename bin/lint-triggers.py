#!/usr/bin/env python3
"""lint-triggers: evals/triggers.json covers every skill, fairly.

Every skill in every plugin has an entry with at least 3 "should" requests and
2 near misses; every near miss's "expect" is a skill name or null; no request
repeats; and no "should" request contains a phrase of two or more words quoted in
the skill's own description (a single quoted word is usually a product or
language name a real request would use), so a pass means Claude matched the intent, not copied words.
Prints the counts checked; exits 1 on any problem or when nothing was checked.
"""

import glob
import json
import os
import re
import subprocess
import sys

KIT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    skills = {}
    for f in sorted(
        glob.glob(os.path.join(KIT, "plugins", "*", "skills", "*", "SKILL.md"))
    ):
        desc = subprocess.run(
            [sys.executable, os.path.join(KIT, "bin", "skill-desc.py"), f],
            capture_output=True,
            text=True,
        ).stdout
        skills[os.path.basename(os.path.dirname(f))] = [
            q.lower() for q in re.findall(r'"([^"]+)"', desc) if " " in q.strip()
        ]
    with open(os.path.join(KIT, "evals", "triggers.json")) as f:
        spec = json.load(f)
    if not skills or not spec:
        print(f"lint-triggers: {len(skills)} skills, {len(spec)} entries; nothing checked", file=sys.stderr)
        return 1
    problems, seen, prompts = [], set(), 0
    entries = {}
    for e in spec:
        name = e.get("skill")
        if name not in skills:
            problems.append(f"{name}: not a skill")
            continue
        if name in entries:
            problems.append(f"{name}: listed twice")
        entries[name] = e
        should, near = e.get("should") or [], e.get("near") or []
        if len(should) < 3:
            problems.append(f"{name}: {len(should)} should requests, want 3")
        if len(near) < 2:
            problems.append(f"{name}: {len(near)} near misses, want 2")
        for p in should:
            for q in skills[name]:
                if q in p.lower():
                    problems.append(
                        f'{name}: should request copies the description phrase "{q}"'
                    )
        for n in near:
            if n.get("expect") is not None and n["expect"] not in skills:
                problems.append(
                    f"{name}: near miss expects unknown skill {n['expect']}"
                )
            if n.get("expect") == name:
                problems.append(f"{name}: near miss expects the skill itself")
        for p in should + [n.get("prompt", "") for n in near]:
            prompts += 1
            if not p.strip():
                problems.append(f"{name}: empty request")
            if "—" in p:
                problems.append(f"{name}: em dash in a request")
            if p.lower() in seen:
                problems.append(f"{name}: request repeated: {p[:60]}")
            seen.add(p.lower())
    for name in skills:
        if name not in entries:
            problems.append(f"{name}: no trigger cases")
    for p in problems:
        print(f"lint-triggers: {p}", file=sys.stderr)
    print(
        f"lint-triggers: {len(entries)} of {len(skills)} skills, {prompts} requests checked, {len(problems)} problems"
    )
    return 1 if problems or not prompts or not skills else 0


if __name__ == "__main__":
    sys.exit(main())
