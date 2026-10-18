#!/usr/bin/env python3
"""lint-model-ids: every Claude model id named under plugins/ is listed in
bin/model-ids.txt (default|<id>|<tier> or option|<id>|<why>). An id is a whole
token: claude-(opus|sonnet|haiku|fable|mythos)-N then every following
letter, digit or hyphen, so a dated snapshot is one id and a run-on id is not
read as its listed prefix. Reads files from git ls-files -co
--exclude-standard when the root is a git work tree, else walks plugins/. Skips binary files. Prints the count of
files scanned and ids found; exit 1 on an unknown id, exit 2 when nothing was
checked (no files, or no ids listed).
Usage: lint-model-ids.py [repository root]
"""
import os
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parents[1]
# A token runs to the first character that cannot be part of an id, so a
# longer run (claude-opus-5-5x, claude-haiku-4-5-2025x) is one unknown id
# rather than a backtracked listed prefix. A trailing hyphen is dropped.
TOKEN = re.compile(r"(?<![A-Za-z0-9-])claude-(?:opus|sonnet|haiku|fable|mythos)-[0-9][A-Za-z0-9-]*")

def nothing(msg):
    print(msg, file=sys.stderr)
    sys.exit(2)


listed = {}
lst = ROOT / "bin" / "model-ids.txt"
if lst.is_file():
    for raw in lst.read_text().splitlines():
        row = raw.strip()
        if not row or row.startswith("#"):
            continue
        parts = row.split("|")
        if len(parts) == 3 and parts[0] in ("default", "option") and parts[1]:
            listed[parts[1]] = parts[0]
if not listed:
    nothing("lint-model-ids: no ids listed in bin/model-ids.txt, nothing checked")


def files_of(root):
    top = root / "plugins"
    if not top.is_dir():
        return []
    try:
        out = subprocess.run(
            ["git", "ls-files", "-co", "--exclude-standard", "-z", "--", "plugins"],
            cwd=root, capture_output=True, check=True,
        ).stdout.decode("utf-8", "replace")
        if (root / ".git").exists():
            return [root / f for f in out.split("\0") if f and (root / f).is_file()]
    except (OSError, subprocess.CalledProcessError):
        pass
    found = []
    for d, _, names in os.walk(top):
        found.extend(pathlib.Path(d) / n for n in names)
    return sorted(f for f in found if f.is_file())


scanned = 0
found = {"default": 0, "option": 0}
bad = []
for f in files_of(ROOT):
    data = f.read_bytes()
    if b"\0" in data[:8192]:
        continue
    scanned += 1
    for n, line in enumerate(data.decode("utf-8", "replace").splitlines(), 1):
        for m in TOKEN.finditer(line):
            tok = m.group(0).rstrip("-")
            kind = listed.get(tok)
            if kind:
                found[kind] += 1
            else:
                bad.append(f"unknown model id {tok} in {f.relative_to(ROOT)}:{n}")
if scanned == 0:
    nothing("lint-model-ids: 0 files under plugins/, nothing checked")
total = found["default"] + found["option"] + len(bad)
if bad:
    print("\n".join(bad), file=sys.stderr)
    sys.exit(f"lint-model-ids: {scanned} files scanned, {total} ids found, {len(bad)} unknown")
print(f"lint-model-ids: {scanned} files scanned, {total} ids found ({found['default']} defaults, {found['option']} options), 0 unknown")
