#!/usr/bin/env python3
"""lint-portable: shell commands that pass on this workstation and fail in CI.

CI runs the unit tests under bash 3.2 in the bash:3.2 image (Alpine, BusyBox,
no perl) and the whole suite on macOS (BSD sed, grep and date). This reads
shell scripts and names, by file and line, each command in command position
(line start, or after |, ||, &&, ;, $( or a backtick) that one of them lacks
or runs differently:

  perl            not installed in the bash:3.2 image
  sed -i          BSD sed takes a suffix argument; use sed -i.bak and remove
                  the .bak, or replace_in from tests/lib/assert.sh
  grep -P         BSD grep has no Perl regex
  readlink -f     older macOS readlink has no -f
  date -d         BSD date parses dates with -j -f

Quoted strings (a guard's deny table), heredoc bodies and comments are not
commands and pass; a command always has an argument, so perl as a case
pattern (ruby|perl|php) is not one.

  lint-portable.py [--root DIR] [<file>...]

With no files it reads every shell script of the repository at DIR (default:
this repository): install.sh, the brg-* scripts, hook scripts, git hooks,
skill scripts and tests. Prints one line per problem and "lint-portable: N
files, P problems"; exits 1 on any problem or when no file is found.
"""

import glob
import os
import re
import sys

LEAD = r"(?:^|\|\|?|&&|;|\$\(|`)\s*"
RULES = [
    ("perl", re.compile(LEAD + r"perl\s")),
    ("sed -i", re.compile(LEAD + r"sed\s+(?:-[a-zA-Z]*\s+)*-i(?=\s)")),
    ("grep -P", re.compile(LEAD + r"grep\s+(?:-[a-zA-Z]+\s+)*-[a-zA-Z]*P")),
    ("readlink -f", re.compile(LEAD + r"readlink\s+-f\b")),
    ("date -d", re.compile(LEAD + r"date\s+-d\b")),
]


def strip(line):
    """The line without its comment, with quoted text blanked. A $( ... )
    inside double quotes is still a command and is kept."""
    out, quote, depth = [], None, 0
    i = 0
    while i < len(line):
        ch = line[i]
        if quote == '"' and depth == 0 and line.startswith("$(", i):
            depth = 1
            out.append("$(")
            i += 2
            continue
        if depth:
            depth += {"(": 1, ")": -1}.get(ch, 0)
            out.append(ch)
        elif quote:
            if ch == quote and line[i - 1] != "\\":
                quote = None
            out.append(" ")
        elif ch in ("'", '"'):
            quote = ch
            out.append(" ")
        elif ch == "#" and (i == 0 or line[i - 1].isspace()):
            break
        else:
            out.append(ch)
        i += 1
    return "".join(out)


def repo_scripts(root):
    """The shell scripts make lint-shell parses, under root."""
    found = []
    for pattern in (
        "install.sh",
        "plugins/*/bin/brg-*",
        "plugins/*/hooks/scripts/*.sh",
        "plugins/*/templates/repo/.githooks/*",
        ".githooks/*",
        "plugins/*/skills/*/scripts/*.sh",
        "tests/**/*.sh",
    ):
        for path in sorted(glob.glob(os.path.join(root, pattern), recursive=True)):
            if not os.path.isfile(path):
                continue
            with open(path, encoding="utf-8", errors="replace") as f:
                first = f.readline()
            if path.endswith(".sh") or "bash" in first or "/sh" in first:
                found.append(path)
    return found


def main(args):
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if args[:1] == ["--root"]:
        root, args = args[1], args[2:]
    paths = args or repo_scripts(root)
    if not paths:
        print(f"lint-portable: 0 files, nothing checked", file=sys.stderr)
        return 1
    problems = 0
    heredoc = re.compile(r"<<-?\s*['\"]?([A-Za-z_][A-Za-z0-9_]*)['\"]?")
    for path in paths:
        end = None  # the word that closes the heredoc being skipped: its body is data
        with open(path, encoding="utf-8", errors="replace") as f:
            for n, raw in enumerate(f, 1):
                if end is not None:
                    if raw.strip() == end:
                        end = None
                    continue
                line = strip(raw.rstrip("\n"))
                m = heredoc.search(raw)
                if m:
                    end = m.group(1)
                for name, rx in RULES:
                    if rx.search(line):
                        problems += 1
                        print(f"problem: {path}:{n}: {name}: {raw.strip()}")
    print(f"lint-portable: {len(paths)} files, {problems} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
