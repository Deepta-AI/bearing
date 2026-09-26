#!/usr/bin/env python3
"""skill-desc: print a SKILL.md frontmatter description as its parsed value.

  skill-desc.py SKILL.md

Handles the one-line forms the skills use: plain, 'single-quoted' (with ''
for a quote) and "double-quoted". Exits 1 when there is no description, so
the lint that calls it counts a missing one as a failure.
"""
import sys

text = open(sys.argv[1], encoding="utf-8").read()
if not text.startswith("---\n"):
    sys.exit(1)
for line in text.split("\n---", 1)[0].splitlines()[1:]:
    if line.startswith("description:"):
        v = line[len("description:"):].strip()
        if len(v) >= 2 and v[0] == v[-1] == "'":
            v = v[1:-1].replace("''", "'")
        elif len(v) >= 2 and v[0] == v[-1] == '"':
            v = v[1:-1].replace('\\"', '"')
        print(v)
        sys.exit(0 if v else 1)
sys.exit(1)
