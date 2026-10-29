#!/usr/bin/env python3
"""lint-listing: Bearing's whole skill listing fits Claude Code's listing budget.

Claude Code lists every skill to the model each turn within a budget (1% of
the context window, skillListingBudgetFraction); past it, skills are listed
by name only and trigger from their name alone. On 28 Oct 2026 Bearing's
listing was about 25,800 characters against a budget of about 22,000 in
the default model: the 16 skills loaded last (bearing-apps react and
react-native, and bearing-genai) were shown by name only and loaded on 12 of
33 requests (20 of 33 with the budget raised). This lint keeps the listing,
as plugin:name plus description for every skill, under LIMIT characters, a
margin under that budget. A smaller-context model has a smaller budget;
see docs/INSTALL.md, Keep the skill listing lean.

Usage: lint-listing.py [--limit N]
Prints "lint-listing: N skills, C characters (limit L), longest ..."; exits 1
over the limit or when no skill was found.
"""

import argparse
import os
import subprocess
import sys

KIT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(KIT, "bin"))
import kit_paths  # noqa: E402

LIMIT = 19000
OVERHEAD = 6  # the separators Claude Code puts around each entry, roughly


def description(skill_md):
    p = subprocess.run(
        [sys.executable, os.path.join(KIT, "bin", "skill-desc.py"), str(skill_md)],
        capture_output=True,
        text=True,
    )
    return p.stdout.strip() if p.returncode == 0 else ""


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--limit", type=int, default=LIMIT)
    a = ap.parse_args()
    rows = []
    for d in kit_paths.skill_dirs():
        plugin = kit_paths.plugin_of(d)
        desc = description(d / "SKILL.md")
        rows.append(
            (
                len(f"{plugin}:{d.name}") + len(desc) + OVERHEAD,
                f"{plugin}:{d.name}",
                len(desc),
            )
        )
    if not rows:
        print("lint-listing: 0 skills found, nothing checked", file=sys.stderr)
        return 1
    total = sum(r[0] for r in rows)
    longest = max(rows, key=lambda r: r[2])
    print(
        f"lint-listing: {len(rows)} skills, {total} characters (limit {a.limit}), "
        f"average description {sum(r[2] for r in rows) / len(rows):.0f}, longest {longest[1]} {longest[2]}"
    )
    if total > a.limit:
        print(
            f"lint-listing: the listing is {total - a.limit} characters over; shorten descriptions "
            f"(job and the words people use first)",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
