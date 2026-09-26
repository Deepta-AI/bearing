#!/usr/bin/env python3
"""flags_check: the flags module, the register and the code agree, every
flag has an owner and a removal date that has not passed, and nothing reads
a flag around the module, computed from the files.

  - Module: --module, else the first that exists of the stack paths
    internal/flags/flags.go, app/flags.py, src/lib/flags.ts,
    domain/flags/Flags.kt, Packages/*/Sources/Core/Flags.swift. Its flag
    keys are the snake_case string literals bound to a name
    (`X Flag = "new_checkout"`, `X = "new_checkout"`, `x: "new_checkout"`,
    `X("new_checkout")`, `case x = "new_checkout"`).
  - Register: docs/operations/flags.md; the "Active flags" table gives
    flag, owner, removal task and target date by column header; the
    "Removed flags" table lists flags that must be gone from the module.
  - Problems: a flag in the module and not the register or the reverse; a
    removed flag still in the module; an empty or `tbd` owner; a target
    date that is missing, not YYYY-MM-DD, or before --today; a read around
    the module: a flag key as a quoted string, or FLAG_<KEY> /
    VITE_FLAG_<KEY>, or any os.Getenv("FLAG_, process.env.FLAG_,
    import.meta.env.VITE_FLAG_, BuildConfig.FLAG_, os.environ...FLAG_,
    in a source file (.go .py .ts .tsx .js .jsx .mjs .kt .swift) other than
    the module.
  - A removal task of `tbd` is counted, not failed (the skill lists it
    under Not done).

Usage: flags_check.py [--module M] [--register R] [--root .] [--today D]
Prints one "problem:" line per failure and the counts; exits 1 on any
problem, when neither a module nor a register exists, or when zero source
files were scanned. Zero flags in both, with files scanned, is a pass.
"""

import argparse
import datetime
import glob
import os
import re
import sys

MODULES = [
    "internal/flags/flags.go",
    "app/flags.py",
    "src/lib/flags.ts",
    "domain/flags/Flags.kt",
    "Packages/*/Sources/Core/Flags.swift",
]
SRC_EXT = (".go", ".py", ".ts", ".tsx", ".js", ".jsx", ".mjs", ".kt", ".swift")
SKIP_DIRS = {
    ".git",
    "node_modules",
    "vendor",
    "dist",
    "build",
    ".venv",
    "venv",
    "__pycache__",
    ".bearing",
    "Pods",
}
KEY_BIND = re.compile(r"""(?:=\s*|:\s*|\(\s*)["']([a-z][a-z0-9]*(?:_[a-z0-9]+)*)["']""")
ENV_READ = re.compile(
    r"""os\.Getenv\(\s*"FLAG_|process\.env\.FLAG_|process\.env\[\s*["']FLAG_|import\.meta\.env\.VITE_FLAG_|BuildConfig\.FLAG_|os\.environ[^\n]{0,20}FLAG_|getenv\(\s*["']FLAG_"""
)
NOT_KEYS = {
    "true",
    "false",
    "debug",
    "info",
    "warn",
    "error",
    "on",
    "off",
    "env",
    "flags",
}


def read(p):
    return (
        open(p, encoding="utf-8", errors="replace").read()
        if p and os.path.isfile(p)
        else None
    )


def find_module(root):
    for pat in MODULES:
        hits = sorted(glob.glob(os.path.join(root, pat)))
        if hits:
            return os.path.normpath(hits[0])
    return None


def table(text, heading):
    """rows as dicts keyed by the lower-cased header, for the table under heading."""
    m = re.search(r"^#{2,4}\s+" + heading + r".*$", text or "", re.M)
    if not m:
        return []
    header, rows = None, []
    for line in text[m.end() :].split("\n"):
        if re.match(r"^#{1,4}\s", line):
            break
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if header is None:
            header = [c.lower() for c in cells]
            continue
        if all(re.match(r"^:?-+:?$", c) for c in cells if c):
            continue
        rows.append(dict(zip(header, cells)))
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--module", default=None)
    ap.add_argument("--register", default="docs/operations/flags.md")
    ap.add_argument("--root", default=".")
    ap.add_argument("--today", default=datetime.date.today().isoformat())
    a = ap.parse_args()

    module = a.module or find_module(a.root)
    mod_text = read(module)
    reg_text = read(a.register)
    if mod_text is None and reg_text is None:
        print(
            f"feature-flags: no flags module ({', '.join(MODULES)}) and no register at {a.register}, nothing checked",
            file=sys.stderr,
        )
        return 1
    problems = []
    mod_keys = []
    for line in (mod_text or "").split("\n"):
        if line.strip().startswith(("//", "#", "*", "/*")):
            continue
        for k in KEY_BIND.findall(line):
            if k not in NOT_KEYS and k not in mod_keys:
                mod_keys.append(k)
    active = table(reg_text, "Active flags")
    removed = table(reg_text, "Removed flags")
    reg = {}
    for r in active:
        name = r.get("flag", "").strip("` ")
        if name and not re.match(r"^<.*>$", name):
            reg[name] = r
    if mod_text is None:
        problems.append(f"no flags module found; the register lists {len(reg)} flags")
    if reg_text is None:
        problems.append(
            f"no register at {a.register}; the module has {len(mod_keys)} flags"
        )

    removed_names = {r.get("flag", "").strip("` ") for r in removed}
    for k in mod_keys:
        if k in removed_names:
            problems.append(f"{k}: listed as removed but still in {module}")
        elif reg_text is not None and k not in reg:
            problems.append(f"{k}: in {module} but not in the register")
    for k in reg:
        if mod_text is not None and k not in mod_keys:
            problems.append(f"{k}: in the register but not in {module}")

    tbd = past = 0
    for name, r in reg.items():
        owner = r.get("owner", "").strip()
        if not owner or owner.lower() in ("tbd", "none", "-"):
            problems.append(f"{name}: no owner")
        date = r.get("target date", "").strip()
        if not re.match(r"^\d{4}-\d{2}-\d{2}$", date):
            problems.append(f"{name}: no removal date (target date '{date}')")
        elif date < a.today:
            past += 1
            problems.append(f"{name}: removal date {date} is past (today {a.today})")
        task = r.get("removal task", "").strip().lower()
        if task in ("", "tbd", "task: tbd"):
            tbd += 1

    scanned, reads = 0, 0
    mod_abs = os.path.abspath(module) if module else None
    key_res = [
        (
            k,
            re.compile(
                r"""["']"""
                + re.escape(k)
                + r"""["']|\b(?:VITE_)?FLAG_"""
                + re.escape(k.upper())
                + r"\b"
            ),
        )
        for k in set(mod_keys) | set(reg)
    ]
    for d, dirs, files in os.walk(a.root):
        dirs[:] = sorted(x for x in dirs if x not in SKIP_DIRS)
        for f in sorted(files):
            if not f.endswith(SRC_EXT):
                continue
            path = os.path.join(d, f)
            if mod_abs and os.path.abspath(path) == mod_abs:
                continue
            scanned += 1
            for i, line in enumerate((read(path) or "").split("\n"), 1):
                rel = os.path.relpath(path, a.root)
                if ENV_READ.search(line):
                    reads += 1
                    problems.append(
                        f"{rel}:{i}: reads a FLAG_ variable outside the module"
                    )
                    continue
                for k, rx in key_res:
                    if rx.search(line):
                        reads += 1
                        problems.append(f"{rel}:{i}: reads flag {k} outside the module")
                        break

    if scanned == 0:
        print(
            f"feature-flags: 0 source files scanned under {a.root}, nothing checked",
            file=sys.stderr,
        )
        return 1
    for p in problems:
        print(f"problem: {p}")
    mismatches = sum(1 for p in problems if "in the register" in p or "still in" in p)
    print(
        f"feature-flags: {len(mod_keys)} flags in {module or 'no module'}, {len(reg)} in the register, "
        f"{mismatches} mismatches, {past} past their removal date, {tbd} removal tasks tbd, "
        f"{reads} reads outside the module in {scanned} source files, {len(problems)} problems"
    )
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
