"""Shared helpers for the lints: find every skill and read its frontmatter."""

import glob
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def frontmatter(path):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    if not text.startswith("---\n"):
        return {}, text
    head, _, body = text[4:].partition("\n---\n")
    fields = {}
    for line in head.splitlines():
        key, sep, value = line.partition(":")
        if sep:
            value = value.strip()
            if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
                value = value[1:-1]
            fields[key.strip()] = value
    return fields, body


def skills():
    """[(plugin, name, path)] for every plugins/*/skills/*/SKILL.md."""
    out = []
    for path in sorted(glob.glob(os.path.join(ROOT, "plugins", "*", "skills", "*", "SKILL.md"))):
        parts = path.split(os.sep)
        out.append((parts[-4], parts[-2], path))
    return out
