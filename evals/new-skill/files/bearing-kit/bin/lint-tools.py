#!/usr/bin/env python3
"""lint-tools: allowed-tools grants no shell wildcard and no publishing command (ADR-0001)."""

import re
import sys

from skills import frontmatter, skills

WILDCARDS = {"Bash", "Bash(*)", "Bash(bash:*)", "Bash(sh:*)", "Bash(python3:*)", "Bash(git:*)"}
PUBLISH = re.compile(r"git push|git tag(?! --list)|glab mr merge|gh pr merge|deploy|kubectl apply|helm upgrade")


def main():
    found = skills()
    if not found:
        print("lint-tools: 0 skills, nothing checked", file=sys.stderr)
        return 1
    problems, grants = [], 0
    for plugin, name, path in found:
        fm, _ = frontmatter(path)
        tools = [t.strip() for t in re.split(r",\s*(?![^()]*\))", fm.get("allowed-tools", "")) if t.strip()]
        grants += len(tools)
        for t in tools:
            if t in WILDCARDS:
                problems.append(f"{plugin}/{name}: allowed-tools grants {t}; name the command")
            if PUBLISH.search(t):
                problems.append(f"{plugin}/{name}: allowed-tools grants {t}; skills never publish (ADR-0001)")
    for p in problems:
        print(f"problem: {p}")
    print(f"lint-tools: {len(found)} skills, {grants} grants, {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
