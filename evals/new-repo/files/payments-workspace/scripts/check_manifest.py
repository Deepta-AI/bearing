#!/usr/bin/env python3
"""Validate repos.yaml, or clone the missing repositories with --clone.

Rules (docs/service-conventions.md): names unique; services and workers
have a port in 8100-8199 that no other entry, retired ones included, has
ever used; command-line tools have no port; owners are a payments group.
Prints the count of entries checked and fails on an empty list.
"""

import os
import re
import subprocess
import sys

KINDS = {"service", "worker", "cli"}
LANGS = {"go", "python"}


def value(raw):
    raw = re.sub(r"\s+#.*$", "", raw).strip()
    if len(raw) >= 2 and raw[0] == raw[-1] and raw[0] in "\"'":
        return raw[1:-1]
    return int(raw) if raw.isdigit() else raw


def load(path):
    """Read the flat shape repos.yaml uses (standard library only): top-level
    keys, and a `repos:` list of one-level mappings."""
    data, repos, cur = {}, [], None
    for line in open(path, encoding="utf-8"):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        m = re.match(r"^(\s*)(- )?([a-z_]+):\s*(.*)$", line.rstrip("\n"))
        if not m:
            raise SystemExit(f"check-manifest: cannot read line: {line.rstrip()}")
        indent, item, key, raw = m.groups()
        if not indent and not item:
            if key == "repos":
                data["repos"] = repos
            else:
                data[key] = value(raw)
            continue
        if item:
            cur = {}
            repos.append(cur)
        cur[key] = value(raw)
    return data


def main(argv):
    clone = "--clone" in argv
    path = [a for a in argv if not a.startswith("--")][0]
    data = load(path)
    repos = data.get("repos") or []
    problems, names, ports = [], set(), {}
    for r in repos:
        n = r.get("name", "?")
        if n in names:
            problems.append(f"{n}: duplicate name")
        names.add(n)
        if r.get("kind") not in KINDS:
            problems.append(f"{n}: kind must be one of {sorted(KINDS)}")
        if r.get("lang") not in LANGS:
            problems.append(f"{n}: lang must be one of {sorted(LANGS)}")
        if not str(r.get("owners", "")).startswith("@payments/"):
            problems.append(f"{n}: owners must be a @payments/ group")
        port = r.get("port")
        if r.get("kind") in ("service", "worker"):
            if not isinstance(port, int) or not 8100 <= port <= 8199:
                problems.append(f"{n}: a {r.get('kind')} needs a port in 8100-8199")
            elif port in ports:
                problems.append(f"{n}: port {port} already used by {ports[port]}")
            else:
                ports[port] = n
        elif port is not None:
            problems.append(f"{n}: a cli has no port")
    for p in problems:
        print(f"problem: {p}")
    if not repos:
        print("check-manifest: 0 repositories, nothing checked", file=sys.stderr)
        return 1
    print(f"check-manifest: {len(repos)} repositories checked, {len(problems)} problems")
    if problems:
        return 1
    if clone:
        host, group = data["gitlab"], data["group"]
        for r in repos:
            if r.get("status") == "retired" or os.path.isdir(r["name"]):
                continue
            url = f"git@{host}:{group}/{r['name']}.git"
            subprocess.run(["git", "clone", url, r["name"]], check=True)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
