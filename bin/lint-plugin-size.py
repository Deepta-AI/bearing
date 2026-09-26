#!/usr/bin/env python3
"""lint-plugin-size: the plugin directory's limits, per plugin folder under
plugins/: fewer than 512 files, and no file of 256 KiB or more unless it is an
image or a font. Counts what a git-sourced install ships: tracked files plus
untracked files .gitignore does not exclude (git ls-files -co
--exclude-standard). Prints the count per plugin; fails on zero plugins.
Usage: lint-plugin-size.py [repository root]
"""
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parents[1]
MAX_FILES = 512
MAX_BYTES = 256 * 1024
EXEMPT = {
    ".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg", ".ico", ".avif", ".bmp", ".tif", ".tiff",
    ".woff", ".woff2", ".ttf", ".otf", ".eot",
}

plugins = sorted(p.parent.parent for p in (ROOT / "plugins").glob("*/.claude-plugin/plugin.json"))
if not plugins:
    sys.exit("lint-plugin-size: 0 plugins under plugins/, nothing checked")
bad = 0
lines = []
for p in plugins:
    rel = p.relative_to(ROOT)
    out = subprocess.run(
        ["git", "ls-files", "-co", "--exclude-standard", "-z", "--", str(rel)],
        cwd=ROOT, capture_output=True, text=True, check=True,
    ).stdout
    files = [ROOT / f for f in out.split("\0") if f and (ROOT / f).is_file()]
    if not files:
        print(f"lint-plugin-size: {rel} lists 0 files", file=sys.stderr)
        bad += 1
        continue
    big = [
        (f, f.stat().st_size) for f in files
        if f.suffix.lower() not in EXEMPT and f.stat().st_size >= MAX_BYTES
    ]
    largest = max((f.stat().st_size for f in files if f.suffix.lower() not in EXEMPT), default=0)
    if len(files) >= MAX_FILES:
        print(f"lint-plugin-size: {rel} has {len(files)} files, the limit is under {MAX_FILES}", file=sys.stderr)
        bad += 1
    for f, size in big:
        print(f"lint-plugin-size: {f.relative_to(ROOT)} is {size // 1024} KiB, the limit is under 256 KiB", file=sys.stderr)
        bad += 1
    lines.append(f"{p.name} {len(files)} files (largest non-image {largest // 1024} KiB)")
if bad:
    sys.exit(f"lint-plugin-size: {bad} problems in {len(plugins)} plugins")
print(f"lint-plugin-size: {len(plugins)} plugins under {MAX_FILES} files and 256 KiB a file: " + "; ".join(lines))
