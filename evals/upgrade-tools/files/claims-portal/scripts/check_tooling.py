#!/usr/bin/env python3
"""Check the agent tooling matches .claude/tooling.lock.

Each source is checked out at its pinned commit with the pinned VERSION,
every local patch for it is applied, every gstack skill is linked into
.claude/skills, and every enabled plugin's marketplace is a locked source.
Fails when the lock lists no sources.
"""

import glob
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def git(path, *args):
    return subprocess.run(["git", "-C", path, *args], capture_output=True, text=True)


def main():
    os.chdir(ROOT)
    lock = json.load(open(".claude/tooling.lock"))["sources"]
    problems, patches, links = [], 0, 0
    by_path = {}
    for s in lock:
        path = s["path"]
        by_path[os.path.normpath(path)] = s["name"]
        if not os.path.isdir(os.path.join(path, ".git")):
            problems.append(f"{s['name']}: no checkout at {path}; run make bootstrap")
            continue
        head = git(path, "rev-parse", "HEAD").stdout.strip()
        if head != s["ref"]:
            problems.append(f"{s['name']}: {path} is at {head[:12]}, lock says {s['ref'][:12]}")
        try:
            version = open(os.path.join(path, "VERSION")).read().strip()
        except OSError:
            version = "?"
        if version != s["version"]:
            problems.append(f"{s['name']}: VERSION is {version}, lock says {s['version']}")
        for p in sorted(glob.glob(f".claude/patches/{s['name']}-*.patch")):
            patches += 1
            if git(path, "apply", "--check", "-R", os.path.abspath(p)).returncode != 0:
                problems.append(f"{s['name']}: {p} is not applied")
    gstack = ".claude/skills/gstack"
    if os.path.isdir(gstack):
        for skill in sorted(glob.glob(f"{gstack}/*/SKILL.md")):
            name = os.path.basename(os.path.dirname(skill))
            links += 1
            link = os.path.join(".claude/skills", name)
            if os.path.realpath(link) != os.path.realpath(os.path.dirname(skill)):
                problems.append(f"gstack: skill {name} is not linked at {link}; run ./setup")
    settings = json.load(open(".claude/settings.json"))
    markets = settings.get("extraKnownMarketplaces", {})
    for plugin, on in settings.get("enabledPlugins", {}).items():
        market = plugin.split("@", 1)[1]
        src = markets.get(market, {}).get("source", {})
        if os.path.normpath(src.get("path", "")) not in by_path:
            problems.append(f"{plugin}: marketplace {market} is not a locked source")
    for p in problems:
        print(f"problem: {p}")
    print(f"check_tooling: {len(lock)} sources, {links} gstack links, {patches} patches, {len(problems)} problems")
    if not lock:
        print("check_tooling: 0 sources in the lock, nothing checked", file=sys.stderr)
        return 1
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
