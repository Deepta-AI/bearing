#!/usr/bin/env python3
"""lint-skills: name, frontmatter, description, sections and length of every skill."""

import os
import re
import sys

from skills import ROOT, frontmatter, skills

NAME = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
SECTIONS = ["## Inputs", "## Steps", "## Output contract", "## Gotchas"]


def main():
    found = skills()
    if not found:
        print("lint-skills: 0 skills, nothing checked", file=sys.stderr)
        return 1
    problems = []
    seen = {}
    for plugin, name, path in found:
        where = f"{plugin}/{name}"
        fm, body = frontmatter(path)
        if not NAME.match(name) or len(name) > 64:
            problems.append(f"{where}: name is not lowercase-hyphenated (64 max)")
        if fm.get("name") != name:
            problems.append(f"{where}: frontmatter name {fm.get('name')!r} differs from the folder")
        if name in seen:
            problems.append(f"{where}: name already used in {seen[name]}")
        seen[name] = plugin
        desc = fm.get("description", "")
        if not desc:
            problems.append(f"{where}: no description")
        if len(desc) > 220:
            problems.append(f"{where}: description is {len(desc)} characters (220 max)")
        if "Use when" not in desc or len(re.findall(r'"[^"]+"', desc)) < 2:
            problems.append(f"{where}: description needs 'Use when' and two quoted phrases")
        if "allowed-tools" not in fm:
            problems.append(f"{where}: no allowed-tools")
        for s in SECTIONS:
            if s not in body:
                problems.append(f"{where}: no '{s}' section")
        with open(path, encoding="utf-8") as f:
            lines = sum(1 for _ in f)
        if lines >= 140:
            problems.append(f"{where}: {lines} lines (under 140)")
        for ref in re.findall(r"\((?:references|templates)/[^)\s]+\)", body):
            if not os.path.exists(os.path.join(os.path.dirname(path), ref[1:-1])):
                problems.append(f"{where}: {ref[1:-1]} does not exist")
    for p in problems:
        print(f"problem: {p}")
    print(f"lint-skills: {len(found)} skills, {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
