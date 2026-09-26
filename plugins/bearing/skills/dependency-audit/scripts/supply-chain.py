#!/usr/bin/env python3
"""supply-chain: the two dependency checks an audit tool does not make.

  supply-chain.py [--root DIR]

1. Lockfiles. Every manifest found (to depth 3, outside vendored and build
   directories) needs its lockfile next to it, and the lockfile must be
   tracked by git. A missing lockfile is a finding (HIGH for an application;
   a library may leave it out on purpose, and the skill judges that); a
   lockfile on disk that git does not track is a finding (MEDIUM).
   Manifests without a lock convention (Gradle without dependency locking)
   are counted and reported as "no lock convention", never as clean.

2. Install scripts in production dependencies. For every package.json with
   a hydrated node_modules, the closure of `dependencies` (not
   devDependencies) is resolved the way Node does (nested node_modules,
   then each ancestor's, which also follows pnpm's symlinked store) and
   every package with a preinstall, install or postinstall script is
   listed. node-gyp style native builds (a binding.gyp, or a script that is
   only `node-gyp rebuild`) are listed as expected, not as findings.
   A package.json without node_modules is reported as "not hydrated": the
   check needs an install first, and nothing is claimed clean.

Prints one line per finding and the count line
  supply-chain: M manifests, L lockfiles tracked, X missing, U untracked,
  P production packages scanned, S with install scripts (E expected)
and exits 1 on any finding, or when zero manifests were found.
"""

import argparse
import json
import os
import subprocess
import sys

SKIP_DIRS = {
    "node_modules",
    "vendor",
    ".git",
    "dist",
    "build",
    ".venv",
    "venv",
    ".terraform",
    "Pods",
    ".build",
    "target",
}
# manifest file name -> the lockfiles that satisfy it (any one of them)
LOCKS = {
    "package.json": [
        "pnpm-lock.yaml",
        "package-lock.json",
        "yarn.lock",
        "bun.lock",
        "bun.lockb",
    ],
    "go.mod": ["go.sum"],
    "pyproject.toml": ["uv.lock", "poetry.lock", "pdm.lock", "Pipfile.lock"],
    "Pipfile": ["Pipfile.lock"],
    "Cargo.toml": ["Cargo.lock"],
    "Gemfile": ["Gemfile.lock"],
    "Package.swift": ["Package.resolved"],
    "Podfile": ["Podfile.lock"],
    "pubspec.yaml": ["pubspec.lock"],
    "composer.json": ["composer.lock"],
}
NO_LOCK_CONVENTION = {"build.gradle.kts", "build.gradle"}
INSTALL_HOOKS = ("preinstall", "install", "postinstall")


def find_manifests(root, depth=3):
    found = []
    root = os.path.abspath(root)
    for dirpath, dirnames, filenames in os.walk(root):
        rel = os.path.relpath(dirpath, root)
        level = 0 if rel == "." else rel.count(os.sep) + 1
        dirnames[:] = sorted(
            d for d in dirnames if d not in SKIP_DIRS and not d.startswith(".")
        )
        if level >= depth:
            dirnames[:] = []
        for fn in sorted(filenames):
            if fn in LOCKS or fn in NO_LOCK_CONVENTION:
                found.append(os.path.join(dirpath, fn))
        if any(fn.endswith(".tf") for fn in filenames):
            found.append(os.path.join(dirpath, "*.tf"))
    return found


def git_tracked(root, path):
    r = subprocess.run(
        ["git", "-C", root, "ls-files", "--error-unmatch", "--", path],
        capture_output=True,
        text=True,
    )
    return r.returncode == 0


def go_has_requires(path):
    try:
        with open(path, encoding="utf-8") as f:
            return any(line.strip().startswith("require") for line in f)
    except OSError:
        return False


def check_locks(root, manifests, findings):
    tracked = missing = untracked = no_convention = 0
    for m in manifests:
        d, fn = os.path.dirname(m), os.path.basename(m)
        rel_d = os.path.relpath(d, root)
        where = fn if rel_d == "." else os.path.join(rel_d, fn)
        if fn in NO_LOCK_CONVENTION:
            no_convention += 1
            if not os.path.exists(os.path.join(d, "gradle.lockfile")):
                print("note: %s has no lock convention (Gradle locking off)" % where)
                continue
            candidates = ["gradle.lockfile"]
        elif fn == "*.tf":
            candidates = [".terraform.lock.hcl"]
        else:
            candidates = LOCKS[fn]
        if fn == "go.mod" and not go_has_requires(m):
            continue
        present = [c for c in candidates if os.path.exists(os.path.join(d, c))]
        if not present:
            missing += 1
            findings.append(
                "lockfile missing: %s (expected one of %s)"
                % (where, ", ".join(candidates))
            )
            continue
        for c in present:
            rel = os.path.relpath(os.path.join(d, c), root)
            if git_tracked(root, rel):
                tracked += 1
            else:
                untracked += 1
                findings.append("lockfile not tracked by git: %s" % rel)
    return tracked, missing, untracked, no_convention


def read_json(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def resolve(from_dir, name):
    """Node's lookup: from_dir/node_modules/name, then each ancestor's."""
    d = os.path.realpath(from_dir)
    while True:
        if os.path.basename(d) != "node_modules":
            cand = os.path.join(d, "node_modules", name)
            if os.path.isfile(os.path.join(cand, "package.json")):
                return os.path.realpath(cand)
        parent = os.path.dirname(d)
        if parent == d:
            return None
        d = parent


def expected_native(pkg_dir, scripts):
    if os.path.exists(os.path.join(pkg_dir, "binding.gyp")):
        return True
    cmds = [scripts.get(h, "") for h in INSTALL_HOOKS if scripts.get(h)]
    return bool(cmds) and all(
        c.strip()
        in (
            "node-gyp rebuild",
            "node-gyp-build",
            "prebuild-install || node-gyp rebuild",
        )
        for c in cmds
    )


def check_install_scripts(root, manifests, findings):
    scanned = with_scripts = expected = 0
    for m in manifests:
        if os.path.basename(m) != "package.json":
            continue
        d = os.path.dirname(m)
        rel_d = os.path.relpath(d, root)
        top = read_json(m) or {}
        deps = sorted((top.get("dependencies") or {}).keys())
        if not deps:
            continue
        if not os.path.isdir(os.path.join(d, "node_modules")) and not resolve(
            d, deps[0]
        ):
            findings.append(
                "not hydrated: %s has %d production dependencies and no node_modules; install first"
                % (os.path.normpath(os.path.join(rel_d, "package.json")), len(deps))
            )
            continue
        seen = set()
        queue = [(d, n) for n in deps]
        while queue:
            base, name = queue.pop()
            pkg_dir = resolve(base, name)
            if pkg_dir is None:
                if base == d:
                    findings.append(
                        "production dependency not installed: %s (from %s)"
                        % (name, os.path.normpath(os.path.join(rel_d, "package.json")))
                    )
                continue
            if pkg_dir in seen:
                continue
            seen.add(pkg_dir)
            pkg = read_json(os.path.join(pkg_dir, "package.json")) or {}
            scanned += 1
            scripts = pkg.get("scripts") or {}
            hooks = [h for h in INSTALL_HOOKS if scripts.get(h)]
            if hooks:
                with_scripts += 1
                label = "%s@%s" % (pkg.get("name", name), pkg.get("version", "?"))
                if expected_native(pkg_dir, scripts):
                    expected += 1
                    print(
                        "expected: %s runs %s (native build)"
                        % (label, ", ".join(hooks))
                    )
                else:
                    findings.append(
                        "install script in a production dependency: %s runs %s: %s"
                        % (label, ", ".join(hooks), scripts[hooks[0]][:80])
                    )
            for dep in sorted((pkg.get("dependencies") or {}).keys()):
                queue.append((pkg_dir, dep))
            for dep in sorted((pkg.get("optionalDependencies") or {}).keys()):
                if resolve(pkg_dir, dep):
                    queue.append((pkg_dir, dep))
    return scanned, with_scripts, expected


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=".")
    args = ap.parse_args()
    root = os.path.abspath(args.root)
    manifests = find_manifests(root)
    findings = []
    if not manifests:
        print(
            "supply-chain: 0 manifests under %s, nothing checked" % root,
            file=sys.stderr,
        )
        sys.exit(1)
    tracked, missing, untracked, _ = check_locks(root, manifests, findings)
    scanned, with_scripts, expected = check_install_scripts(root, manifests, findings)
    for f in findings:
        print(("not checked: " if f.startswith("not hydrated") else "finding: ") + f)
    print(
        "supply-chain: %d manifests, %d lockfiles tracked, %d missing, %d untracked, "
        "%d production packages scanned, %d with install scripts (%d expected)"
        % (len(manifests), tracked, missing, untracked, scanned, with_scripts, expected)
    )
    sys.exit(1 if findings else 0)


if __name__ == "__main__":
    main()
