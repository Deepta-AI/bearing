#!/usr/bin/env python3
"""pin-refresh: how far every pinned pack has fallen behind its upstream.

For each row of plugins/bearing/bin/pinned-packs.txt:
  skill, plugin, cli, clone  `git ls-remote` the repository's HEAD; when it
                             moved past the pin, fetch both commits (no file
                             contents beyond what the diff needs) into a cache
                             and name the files that changed under the pinned
                             path (a cli row's path is a skill name, matched
                             anywhere), flagging a changed SKILL.md
  npm, pypi                  the registry's latest version against the pin

It never edits the pin file. Moving a pin is the maintainer's call: read the
diff it names, then change the row (tests/unit/pins_match.sh finds every
other place a version is written).

Usage: pin-refresh.py [--pins F] [--cache D]
Prints one line per pin and "pin-refresh: N pins checked, M behind, K errors";
exits 1 on zero pins or any error, else 0 (being behind is news, not a failure).

  BRG_PIN_GIT_URL   the repository URL template (default https://github.com/{repo}.git)
  BRG_PIN_NPM_URL   default https://registry.npmjs.org/{pkg}/latest
  BRG_PIN_PYPI_URL  default https://pypi.org/pypi/{pkg}/json
"""

import argparse
import json
import os
import subprocess
import sys
import urllib.request

KIT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PINS = os.path.join(KIT, "plugins", "bearing", "bin", "pinned-packs.txt")
GIT_URL = os.environ.get("BRG_PIN_GIT_URL", "https://github.com/{repo}.git")
NPM_URL = os.environ.get("BRG_PIN_NPM_URL", "https://registry.npmjs.org/{pkg}/latest")
PYPI_URL = os.environ.get("BRG_PIN_PYPI_URL", "https://pypi.org/pypi/{pkg}/json")
GIT_KINDS = {"skill", "plugin", "cli", "clone"}


def rows(path):
    out = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                f6 = line.split("|")
                if len(f6) >= 5:
                    out.append(
                        {
                            "kind": f6[0],
                            "source": f6[1],
                            "pin": f6[2],
                            "path": f6[3],
                            "name": f6[4],
                        }
                    )
    return out


def fetch(url):
    """A document: urllib (file:// and http), else curl (a Python without ssl)."""
    try:
        with urllib.request.urlopen(url, timeout=30) as r:
            return r.read().decode()
    except (OSError, ValueError) as e:
        try:
            p = subprocess.run(
                ["curl", "-fsSL", "--max-time", "30", url],
                capture_output=True,
                text=True,
            )
        except OSError:
            raise e
        if p.returncode != 0:
            raise OSError(f"{e}; curl: {p.stderr.strip()}")
        return p.stdout


def git(*args, cwd=None):
    env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
    env["GIT_TERMINAL_PROMPT"] = "0"
    return subprocess.run(
        ["git", *args], cwd=cwd, capture_output=True, text=True, env=env, timeout=120
    )


def upstream_head(url):
    p = git("ls-remote", url, "HEAD")
    if p.returncode != 0 or not p.stdout.split():
        raise OSError(p.stderr.strip()[:200] or "no HEAD")
    return p.stdout.split()[0]


def changed(cache, repo, url, pin, head, row):
    d = os.path.join(cache, repo.replace("/", "__") + ".git")
    if not os.path.isdir(d):
        p = git("init", "-q", "--bare", d)
        if p.returncode != 0:
            raise OSError(p.stderr.strip())
    p = git("fetch", "-q", "--filter=blob:none", url, pin, head, cwd=d)
    if p.returncode != 0:
        raise OSError(f"fetch: {p.stderr.strip()[:200]}")
    spec = f":(glob)**/{row['path']}/**" if row["kind"] == "cli" else row["path"]
    if row["kind"] in ("plugin", "clone") or not row["path"]:
        spec = "."  # a plugin@marketplace or a clone path: the whole repository
    p = git("diff", "--name-only", pin, head, "--", spec, cwd=d)
    if p.returncode != 0:
        raise OSError(f"diff: {p.stderr.strip()[:200]}")
    return [f for f in p.stdout.splitlines() if f.strip()], d


def where(r):
    """The pinned path as a report names it."""
    if r["kind"] in ("plugin", "clone") or not r["path"]:
        return "the whole repository"
    return r["path"]


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--pins", default=PINS)
    ap.add_argument("--cache", default=os.path.join(KIT, ".scratch", "pin-refresh"))
    a = ap.parse_args()

    rs = rows(a.pins)
    if not rs:
        print(f"pin-refresh: 0 pins in {a.pins}; nothing checked", file=sys.stderr)
        return 1
    os.makedirs(a.cache, exist_ok=True)
    heads, behind, errors = {}, 0, 0
    for r in rs:
        label = f"{r['kind']} {r['source']}" + (
            f" {r['name']}" if r["kind"] in GIT_KINDS else ""
        )
        try:
            if r["kind"] in GIT_KINDS:
                url = GIT_URL.format(repo=r["source"])
                if url not in heads:
                    heads[url] = upstream_head(url)
                head = heads[url]
                if head == r["pin"]:
                    print(f"{label}: current")
                    continue
                files, cache = changed(a.cache, r["source"], url, r["pin"], head, r)
                if not files:
                    print(f"{label}: upstream moved, nothing under {where(r)} changed")
                    continue
                behind += 1
                skill_md = (
                    " (SKILL.md changed)"
                    if any(f.endswith("SKILL.md") for f in files)
                    else ""
                )
                print(
                    f"{label}: {r['pin'][:7]} -> {head[:7]}, {len(files)} files changed under {where(r)}{skill_md}; "
                    f"read: git -C {os.path.relpath(cache, KIT)} diff {r['pin'][:12]} {head[:12]}"
                )
            elif r["kind"] in ("npm", "pypi"):
                if r["kind"] == "npm":
                    latest = json.loads(fetch(NPM_URL.format(pkg=r["source"])))[
                        "version"
                    ]
                else:
                    latest = json.loads(fetch(PYPI_URL.format(pkg=r["source"])))[
                        "info"
                    ]["version"]
                if latest == r["pin"]:
                    print(f"{label}: current")
                else:
                    behind += 1
                    print(f"{label}: {r['pin']} -> {latest}")
            else:
                print(f"{label}: unknown kind, skipped")
                errors += 1
        except (OSError, ValueError, KeyError, subprocess.TimeoutExpired) as e:
            errors += 1
            print(f"{label}: error: {e}")
    print(f"pin-refresh: {len(rs)} pins checked, {behind} behind, {errors} errors")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
