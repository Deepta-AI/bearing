#!/usr/bin/env python3
"""claude-code-drift: what Claude Code offers now that Bearing does not use,
and what Bearing uses that Claude Code no longer offers.

It reads the installed CLI (`claude --version`, the flags in `claude --help`)
and the Claude Code settings schema (hook events, settings keys, sandbox
keys), and compares them with docs/claude-code-surface.json, the surface
recorded the last time a maintainer looked. Each run prints what is new since
then (features to consider) and what Bearing uses that is gone: a hook event
in plugins/*/hooks/hooks.json, or a CLI flag the eval scripts pass. Anything
gone fails the run.

--record writes the current surface once the maintainer has read the new
items, so the next run starts from there.

Usage: claude-code-drift.py [--schema FILE|URL] [--surface F] [--record]
Prints "claude-code-drift: <version>, N flags, M hook events, K settings keys;
X new, Y gone"; exits 1 when something used is gone, when there is no recorded
surface (without --record), or when the CLI or the schema cannot be read.
The schema defaults to the published one at SCHEMA_URL (data only; nothing
fetched is run).
"""

import argparse
import glob
import json
import os
import re
import subprocess
import sys
import urllib.request

KIT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CLAUDE = os.environ.get("BRG_CLAUDE", "claude")
SCHEMA_URL = "https://json.schemastore.org/claude-code-settings.json"
SURFACE = os.path.join(KIT, "docs", "claude-code-surface.json")
# The scripts that start claude sessions; the CLI flags they pass must exist.
CALLERS = ["trigger-eval.py", "harness-eval.py", "skill-evals-run.py", "skill-tune.py"]
FLAG = re.compile(r"(?<![\w-])--[A-Za-z][\w-]*")


def die(msg):
    print(f"claude-code-drift: {msg}", file=sys.stderr)
    sys.exit(1)


def cli():
    try:
        v = subprocess.run(
            [CLAUDE, "--version"], capture_output=True, text=True, timeout=30
        ).stdout.split()
        h = subprocess.run(
            [CLAUDE, "--help"], capture_output=True, text=True, timeout=30
        ).stdout
    except (OSError, subprocess.TimeoutExpired) as e:
        die(f"cannot run {CLAUDE}: {e}")
    # An option line is "  -p, --print   description": the flags are the part
    # before the first run of two spaces, so a flag named in a description
    # is not counted.
    flags = set()
    for line in h.splitlines():
        if line.lstrip().startswith("-"):
            flags |= set(FLAG.findall(re.split(r"\s{2,}", line.strip(), maxsplit=1)[0]))
    flags = sorted(flags)
    if not v or not flags:
        die(f"{CLAUDE} printed no version or no flags")
    return v[0], flags


def fetch(url):
    """The document at url: urllib, else curl (a Python built without ssl)."""
    try:
        with urllib.request.urlopen(url, timeout=30) as r:
            return r.read().decode()
    except (OSError, ValueError) as e:
        try:
            p = subprocess.run(["curl", "-fsSL", "--max-time", "30", url], capture_output=True, text=True)
        except OSError:
            raise e
        if p.returncode != 0:
            raise OSError(f"{e}; curl: {p.stderr.strip()}")
        return p.stdout


def load_schema(src):
    try:
        if re.match(r"https?://", src):
            return json.loads(fetch(src))
        with open(src) as f:
            return json.load(f)
    except (OSError, ValueError) as e:
        die(f"cannot read the settings schema {src}: {e}")


def find(node, key):
    """The first object under `key` that has properties, anywhere in the schema."""
    if isinstance(node, dict):
        v = (
            node.get("properties", {}).get(key)
            if isinstance(node.get("properties"), dict)
            else None
        )
        if isinstance(v, dict) and isinstance(v.get("properties"), dict):
            return v["properties"]
        for x in node.values():
            r = find(x, key)
            if r:
                return r
    elif isinstance(node, list):
        for x in node:
            r = find(x, key)
            if r:
                return r
    return None


def surface(schema_src):
    version, flags = cli()
    s = load_schema(schema_src)
    hooks = sorted((find(s, "hooks") or {}).keys())
    keys = sorted((s.get("properties") or {}).keys())
    sandbox = sorted((find(s, "sandbox") or {}).keys())
    if not hooks or not keys:
        die(
            "the settings schema lists no hook events or no settings keys; its layout may have changed"
        )
    return {
        "version": version,
        "flags": flags,
        "hook_events": hooks,
        "settings_keys": keys,
        "sandbox_keys": sandbox,
    }


def used(recorded_flags):
    events = set()
    for f in glob.glob(os.path.join(KIT, "plugins", "*", "hooks", "hooks.json")):
        events |= set((json.load(open(f)).get("hooks") or {}).keys())
    literals = set()
    for name in CALLERS:
        p = os.path.join(KIT, "bin", name)
        if os.path.isfile(p):
            literals |= set(re.findall(r"[\"'](--[A-Za-z][\w-]*)[\"']", open(p).read()))
    # Only literals that were CLI flags when recorded: the scripts' own options
    # (--only, --max) are literals too.
    return sorted(events), sorted(literals & set(recorded_flags))


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--schema", default=SCHEMA_URL)
    ap.add_argument("--surface", default=SURFACE)
    ap.add_argument("--record", action="store_true")
    a = ap.parse_args()

    now = surface(a.schema)
    old = None
    if os.path.isfile(a.surface):
        with open(a.surface) as f:
            old = json.load(f)
    events, flags = used((old or now)["flags"])
    gone = [f"hook event {e}" for e in events if e not in now["hook_events"]]
    gone += [f"flag {f}" for f in flags if f not in now["flags"]]
    new = []
    if old:
        if old.get("version") != now["version"]:
            print(f"  version {old.get('version')} -> {now['version']}")
        for k, label in (
            ("flags", "flag"),
            ("hook_events", "hook event"),
            ("settings_keys", "settings key"),
            ("sandbox_keys", "sandbox key"),
        ):
            new += [f"{label}: {x}" for x in now[k] if x not in old.get(k, [])]
        for x in new:
            print(f"  new {x}")
    unused = [e for e in now["hook_events"] if e not in events]
    if unused:
        print(f"  hook events Bearing does not use: {', '.join(unused)}")
    for g in gone:
        print(f"gone but used: {g}")
    print(
        f"claude-code-drift: {now['version']}, {len(now['flags'])} flags, {len(now['hook_events'])} hook events, "
        f"{len(now['settings_keys'])} settings keys; Bearing uses {len(events)} hook events and {len(flags)} flags; "
        f"{len(new)} new, {len(gone)} gone"
    )
    if a.record:
        os.makedirs(os.path.dirname(os.path.abspath(a.surface)), exist_ok=True)
        with open(a.surface, "w") as f:
            json.dump(now, f, indent=1)
            f.write("\n")
        print(
            f"claude-code-drift: surface recorded in {os.path.relpath(a.surface, KIT)}"
        )
        return 1 if gone else 0
    if old is None:
        print(
            "claude-code-drift: no recorded surface; read the list above, then rerun with --record"
        )
        return 1
    return 1 if gone else 0


if __name__ == "__main__":
    sys.exit(main())
