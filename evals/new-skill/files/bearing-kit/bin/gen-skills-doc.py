#!/usr/bin/env python3
"""gen-skills-doc: the skill table in docs/SKILLS.md, generated from frontmatter.

Usage: gen-skills-doc.py [--check]   (--check exits 1 when the file is stale)
"""

import os
import sys

from skills import ROOT, frontmatter, skills

DOC = os.path.join(ROOT, "docs", "SKILLS.md")
START, END = "<!-- skills:start -->", "<!-- skills:end -->"


def table():
    rows = ["| Skill | Plugin | What it does |", "|---|---|---|"]
    for plugin, name, path in skills():
        desc = frontmatter(path)[0].get("description", "").split(" Use when")[0]
        rows.append(f"| `{name}` | {plugin} | {desc} |")
    return "\n".join(rows), len(rows) - 2


def main():
    with open(DOC, encoding="utf-8") as f:
        text = f.read()
    head, _, rest = text.partition(START)
    _, _, tail = rest.partition(END)
    body, n = table()
    if n == 0:
        print("gen-skills-doc: 0 skills, nothing generated", file=sys.stderr)
        return 1
    new = f"{head}{START}\n{body}\n{END}{tail}"
    if "--check" in sys.argv:
        if new != text:
            print("docs/SKILLS.md is stale; run make docs")
            return 1
        print(f"docs-check: {n} skills, table current")
        return 0
    with open(DOC, "w", encoding="utf-8") as f:
        f.write(new)
    print(f"gen-skills-doc: {n} skills written to docs/SKILLS.md")
    return 0


if __name__ == "__main__":
    sys.exit(main())
