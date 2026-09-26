"""Where the Bearing plugins sit in this repository, for the repository's own
tools (generators, lints, the eval harness). Bearing ships as three plugins
from one marketplace: plugins/bearing (the workflow, agents, hooks, bin and
templates), plugins/bearing-backend and plugins/bearing-apps (the stack
skills). The answer comes from plugins/bearing/bin/brg-kit-paths, the same
resolver the plugin's own scripts use, so the two never disagree.
"""

import os
import pathlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
BEARING = ROOT / "plugins" / "bearing"
RESOLVER = BEARING / "bin" / "brg-kit-paths"


def _run(*args):
    env = {k: v for k, v in os.environ.items() if k != "BEARING_PLUGIN_DIRS"}
    r = subprocess.run(
        ["bash", str(RESOLVER), *args], capture_output=True, text=True, env=env
    )
    if r.returncode != 0:
        raise SystemExit(
            f"brg-kit-paths {' '.join(args)}: {r.stderr.strip() or 'failed'}"
        )
    return [line for line in r.stdout.splitlines() if line.strip()]


def plugins():
    """{name: root} for every Bearing plugin in the repository, bearing first."""
    out = {}
    for line in _run("--plugins"):
        name, root = line.split("\t", 1)
        out[name] = pathlib.Path(root)
    return out


def skill_roots():
    """The skills/ folder of every Bearing plugin, bearing first."""
    return [pathlib.Path(p) for p in _run("--skills")]


def skill_dirs():
    """Every skill directory (one holding SKILL.md) across the plugins, by name."""
    dirs = [d for r in skill_roots() for d in r.iterdir() if (d / "SKILL.md").is_file()]
    return sorted(dirs, key=lambda d: d.name)


def skill_dir(name):
    """The directory of one skill, or None."""
    for r in skill_roots():
        if (r / name / "SKILL.md").is_file():
            return r / name
    return None


def plugin_of(path):
    """The plugin name a path belongs to (bearing, bearing-backend, bearing-apps)."""
    p = pathlib.Path(path).resolve()
    for name, root in plugins().items():
        if root == p or root in p.parents:
            return name
    return None
