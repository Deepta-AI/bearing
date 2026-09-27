#!/usr/bin/env python3
"""validate-plugins: the marketplace and every plugin manifest parse and agree on the version."""

import json
import os
import sys

from skills import ROOT


def main():
    problems = []
    market = json.load(open(os.path.join(ROOT, ".claude-plugin", "marketplace.json")))
    version = open(os.path.join(ROOT, "VERSION")).read().strip()
    plugins = market.get("plugins") or []
    if not plugins:
        print("validate: 0 plugins, nothing checked", file=sys.stderr)
        return 1
    if market.get("metadata", {}).get("version") != version:
        problems.append("marketplace metadata version differs from VERSION")
    for p in plugins:
        path = os.path.join(ROOT, p["source"], ".claude-plugin", "plugin.json")
        if not os.path.exists(path):
            problems.append(f"{p['name']}: no plugin.json")
            continue
        manifest = json.load(open(path))
        if manifest.get("name") != p["name"]:
            problems.append(f"{p['name']}: plugin.json name is {manifest.get('name')!r}")
        if manifest.get("version") != version or p.get("version") != version:
            problems.append(f"{p['name']}: version differs from VERSION ({version})")
    for x in problems:
        print(f"problem: {x}")
    print(f"validate: {len(plugins)} plugins, {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
