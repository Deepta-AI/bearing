#!/usr/bin/env python3
"""flags_check: the flags module, the register, the code and the deploy
config agree, every flag has an owner and a removal date that has not
passed, and nothing reads a flag around the module, computed from the files.

  - Module: --module, else the first that exists of the stack paths
    internal/flags/flags.go, app/flags.py, src/lib/flags.ts,
    domain/flags/Flags.kt, Packages/*/Sources/Core/Flags.swift. Its flag
    keys are the snake_case string literals bound to a name
    (`X Flag = "new_checkout"`, `X = "new_checkout"`, `x: "new_checkout"`,
    `X("new_checkout")`, `case x = "new_checkout"`).
  - Register: docs/operations/flags.md. The active table is the one under a
    heading containing "Active", else the first table with a Flag column
    that is not under a "Removed" or "Retired" heading, so a team's own
    register is read as it is. Columns are found by header: flag, owner,
    the removal task (a header containing "task" or "ticket") and the target
    date (a header containing "target", "remove by" or "removal date"). The
    table under a "Removed" or "Retired" heading lists flags that must be
    gone from the code and the config.
  - Source files (.go .py .ts .tsx .js .jsx .mjs .kt .swift, and the page
    templates .html .jinja .j2 .tmpl .erb .vue .svelte, where flags
    serialised for the client are read by key) other than the module and
    test files: a read of a flag key as a quoted string or FLAG_<KEY> /
    VITE_FLAG_<KEY>, or any os.Getenv("FLAG_, process.env.FLAG_,
    import.meta.env.VITE_FLAG_, BuildConfig.FLAG_, os.environ...FLAG_, is a
    problem, except that a quoted key of an active flag in a client file
    (.js .jsx .mjs or a template) is listed as a "client read:" line: the
    flags module serialises it for the page, and every such line is a place
    a removal must also change. A read of a REMOVED flag's key is reported
    as such: a client bundle reading window.FLAGS["old"] silently takes the
    off branch forever.
  - Config files (.env, *.env, .env.*, .yaml, .yml, .toml, .json, .ini,
    .properties, .tfvars; lock files skipped): every FLAG_<NAME> setting is
    collected. A setting for a removed flag, or for a name that is not a
    flag at all, is a problem (stale or mistyped config). A removed flag's
    key quoted in a config file (an override map) is a problem. For each
    active flag the values per file and line are printed on a "values:"
    line, marked when deployed environments (example and template files
    aside) disagree, so a flag that is on in one environment and off in
    another is visible before anyone calls it "at 100%".
    An active flag's key quoted in a config file (a per-account or
    per-tenant override map, a remote-config default) is listed on a
    "config names:" line: another value source the module may honour.
    A deployed config file that sets some FLAG_ variable but not this flag's
    is named on the "values:" line as "unset (default) in": that
    environment runs the default, whatever the other files say.
  - Parser: when the module turns a value into a boolean by non-emptiness
    (Go `!= ""`, JS `!!process.env` or `Boolean(process.env`, Python
    `bool(os.environ...)` or `bool(getenv(...))`), every setting of
    false, 0, off or no is a problem: that value reads as ON.
  - Problems also: a flag in the module and not the register or the
    reverse; a removed flag still in the module; an empty or `tbd` owner; a
    target date missing, not YYYY-MM-DD, or before --today.
  - A removal task of `tbd` is counted, not failed.

Usage: flags_check.py [--module M] [--register R] [--root .] [--today D]
Prints one "problem:" line per failure, the "values:" lines and the counts;
exits 1 on any problem, when neither a module nor a register exists, or when
zero source files were scanned. Zero flags in both, with files scanned, is a
pass.
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
SRC_EXT = (
    ".go",
    ".py",
    ".ts",
    ".tsx",
    ".js",
    ".jsx",
    ".mjs",
    ".kt",
    ".swift",
    ".html",
    ".jinja",
    ".j2",
    ".tmpl",
    ".erb",
    ".vue",
    ".svelte",
)
CFG_EXT = (
    ".yaml",
    ".yml",
    ".toml",
    ".json",
    ".ini",
    ".properties",
    ".tfvars",
    ".env",
)
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
CLIENT_EXT = (".js", ".jsx", ".mjs") + SRC_EXT[SRC_EXT.index(".html") :]
EXAMPLE = re.compile(r"example|sample|template|\.dist\b", re.I)
TEST_FILE = re.compile(
    r"(^|/)(tests?|__tests__|spec)/|(^|/)test_[^/]*\.py$|_test\.(go|py)$|\.(test|spec)\.[jt]sx?$|Tests?\.(kt|swift)$"
)
KEY_BIND = re.compile(r"""(?:=\s*|:\s*|\(\s*)["']([a-z][a-z0-9]*(?:_[a-z0-9]+)*)["']""")
ENV_READ = re.compile(
    r"""os\.Getenv\(\s*"FLAG_|process\.env\.FLAG_|process\.env\[\s*["']FLAG_|import\.meta\.env\.VITE_FLAG_|BuildConfig\.FLAG_|os\.environ[^\n]{0,20}FLAG_|getenv\(\s*["']FLAG_"""
)
CFG_SET = re.compile(
    r"""\b(?:VITE_)?FLAG_([A-Z0-9_]+)\b["']?\s*(?:(?:=|:)\s*|,\s*value:\s*)?["']?([^"'\s,}#]*)"""
)
NEXT_VALUE = re.compile(r"""^\s*value:\s*["']?([^"'\s,}#]*)""")
LENIENT = re.compile(
    r"""!=\s*""|!!\s*process\.env|Boolean\(\s*process\.env|bool\(\s*(?:os\.)?(?:environ|getenv)"""
)
OFF_WORDS = {"false", "0", "off", "no"}
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


def tables(text):
    """[(heading, header, rows)] for every markdown table; rows keyed by the lower-cased header."""
    out, heading, header, rows = [], "", None, None
    for line in (text or "").split("\n"):
        m = re.match(r"^#{1,4}\s+(.*)$", line)
        if m:
            heading, header = m.group(1), None
            continue
        if not line.startswith("|"):
            header = None
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if header is None:
            header, rows = [c.lower() for c in cells], []
            out.append((heading, header, rows))
            continue
        if all(re.match(r"^:?-+:?$", c) for c in cells if c):
            continue
        rows.append(dict(zip(header, cells)))
    return out


def col(row, *needles, avoid=()):
    for h, v in row.items():
        if any(n in h for n in needles) and not any(x in h for x in avoid):
            return v.strip()
    return ""


def register(text):
    active, removed = None, []
    ts = tables(text)
    for heading, _, rows in ts:
        if re.search(r"removed|retired", heading, re.I):
            removed += rows
        elif active is None and re.search(r"active", heading, re.I):
            active = rows
    if active is None:
        for heading, header, rows in ts:
            if "flag" in header and not re.search(r"removed|retired", heading, re.I):
                active = rows
                break
    return active or [], removed


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
    active, removed = register(reg_text)
    reg = {}
    for r in active:
        name = col(r, "flag").strip("` ")
        if name and not re.match(r"^<.*>$", name):
            reg[name] = r
    if mod_text is None:
        problems.append(f"no flags module found; the register lists {len(reg)} flags")
    if reg_text is None:
        problems.append(
            f"no register at {a.register}; the module has {len(mod_keys)} flags"
        )

    removed_names = {col(r, "flag").strip("` ") for r in removed} - {""}
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
        owner = col(r, "owner")
        if not owner or owner.lower() in ("tbd", "none", "-"):
            problems.append(f"{name}: no owner")
        date = col(r, "target", "remove by", "removal date", avoid=("added",))
        if not re.match(r"^\d{4}-\d{2}-\d{2}$", date):
            problems.append(f"{name}: no removal date (target date '{date}')")
        elif date < a.today:
            past += 1
            problems.append(f"{name}: removal date {date} is past (today {a.today})")
        task = col(r, "task", "ticket").lower()
        if task in ("", "tbd", "task: tbd"):
            tbd += 1

    live = set(mod_keys) | set(reg)
    gone = removed_names - live

    def key_rx(k):
        return re.compile(
            r"""["']"""
            + re.escape(k)
            + r"""["']|\b(?:VITE_)?FLAG_"""
            + re.escape(k.upper())
            + r"\b"
        )

    live_res = [(k, key_rx(k)) for k in sorted(live)]
    gone_res = [(k, key_rx(k)) for k in sorted(gone)]
    quoted_gone = [
        (k, re.compile(r"""["']""" + re.escape(k) + r"""["']""")) for k in sorted(gone)
    ]
    quoted_live = [
        (k, re.compile(r"""["']""" + re.escape(k) + r"""["']""")) for k in sorted(live)
    ]
    scanned, cfg_scanned, reads = 0, 0, 0
    client, overrides = [], []
    values = {k: [] for k in mod_keys}
    deployed_sets = {}
    lenient = next(
        (
            i
            for i, line in enumerate((mod_text or "").split("\n"), 1)
            if LENIENT.search(line) and not line.strip().startswith(("//", "#"))
        ),
        None,
    )
    mod_abs = os.path.abspath(module) if module else None
    reg_abs = os.path.abspath(a.register)
    for d, dirs, files in os.walk(a.root):
        dirs[:] = sorted(x for x in dirs if x not in SKIP_DIRS)
        for f in sorted(files):
            path = os.path.join(d, f)
            rel = os.path.relpath(path, a.root)
            if os.path.abspath(path) in (mod_abs, reg_abs):
                continue
            is_cfg = (
                f.startswith(".env") or f.endswith(CFG_EXT)
            ) and "lock" not in f.lower()
            if is_cfg:
                cfg_scanned += 1
                lines = (read(path) or "").split("\n")
                for i, line in enumerate(lines, 1):
                    if line.lstrip().startswith(("#", "//")):
                        continue
                    for m in CFG_SET.finditer(line):
                        key, val = m.group(1).lower(), m.group(2)
                        if not val and i < len(lines):
                            n = NEXT_VALUE.match(lines[i])
                            val = n.group(1) if n else ""
                        if not EXAMPLE.search(rel):
                            deployed_sets.setdefault(rel, set()).add(key)
                        if lenient and val.lower() in OFF_WORDS and key in live:
                            problems.append(
                                f"{rel}:{i}: FLAG_{key.upper()}={val} reads as ON: {module}:{lenient} treats any non-empty value as on"
                            )
                        if key in gone:
                            problems.append(f"{rel}:{i}: sets removed flag {key}")
                        elif key in values:
                            values[key].append((f"{rel}:{i}", val or "(empty)"))
                        elif key not in live:
                            problems.append(
                                f"{rel}:{i}: sets FLAG_{key.upper()}, which is not a flag in the module"
                            )
                    for k, rx in quoted_gone:
                        if rx.search(line):
                            problems.append(f"{rel}:{i}: names removed flag {k}")
                    for k, rx in quoted_live:
                        if rx.search(line):
                            overrides.append(f"{rel}:{i}: {k}")
                continue
            if not f.endswith(SRC_EXT):
                continue
            scanned += 1
            if TEST_FILE.search(rel.replace(os.sep, "/")):
                continue
            for i, line in enumerate((read(path) or "").split("\n"), 1):
                if ENV_READ.search(line):
                    reads += 1
                    problems.append(
                        f"{rel}:{i}: reads a FLAG_ variable outside the module"
                    )
                    continue
                hit = next((k for k, rx in gone_res if rx.search(line)), None)
                if hit:
                    reads += 1
                    problems.append(f"{rel}:{i}: reads removed flag {hit}")
                    continue
                hit = next((k for k, rx in live_res if rx.search(line)), None)
                if hit and f.endswith(CLIENT_EXT) and hit in mod_keys:
                    client.append(f"{rel}:{i}: {hit}")
                elif hit:
                    reads += 1
                    problems.append(f"{rel}:{i}: reads flag {hit} outside the module")

    if scanned == 0:
        print(
            f"feature-flags: 0 source files scanned under {a.root}, nothing checked",
            file=sys.stderr,
        )
        return 1
    for p in problems:
        print(f"problem: {p}")
    for k in mod_keys:
        unset = sorted(f for f, keys in deployed_sets.items() if k not in keys)
        if values[k] or unset:
            deployed = {v.lower() for w, v in values[k] if not EXAMPLE.search(w)}
            if unset:
                deployed.add("(unset)")
            mixed = (
                " (differs between deployed environments)" if len(deployed) > 1 else ""
            )
            parts = [w + "=" + v for w, v in values[k]]
            if unset:
                parts.append("unset (default) in " + ", ".join(unset))
            print(f"values: {k}: {', '.join(parts)}{mixed}")
    for c in client:
        print(f"client read: {c}")
    for o in overrides:
        print(f"config names: {o}")
    mismatches = sum(1 for p in problems if "in the register" in p or "still in" in p)
    print(
        f"feature-flags: {len(mod_keys)} flags in {module or 'no module'}, {len(reg)} in the register, "
        f"{mismatches} mismatches, {past} past their removal date, {tbd} removal tasks tbd, "
        f"{reads} reads outside the module in {scanned} source files, "
        f"{len(client)} client reads, {cfg_scanned} config files, {len(problems)} problems"
    )
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
