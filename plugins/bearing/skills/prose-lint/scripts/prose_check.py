#!/usr/bin/env python3
"""prose_check: find the tells of generated prose, line by line, in the
files given, and count them. It finds; the skill rewrites.

  - Files: the paths given (a file of any type is read, so a source file
    named on purpose has its comments linted; a directory is walked for
    .md, .mdx, .txt, .rst, .xcstrings, .strings and strings.xml), plus the
    prose files among the paths listed one per line in --files-from (for
    example `git diff --name-only` output; `-` reads stdin), filtered by
    the same extensions. A listed path that no longer exists (a deleted
    file) is skipped and counted.
  - Classes and patterns:
      em dash: U+2014 anywhere; a table cell holding only the dash is
        typography for "no value" and is counted as left, not a hit.
      filler: delve, leverage, robust, seamless(ly), comprehensive,
        streamline, "it's worth noting", "in today's fast-paced", "I hope
        this helps", "great question", certainly.
      praise: "as requested", "as you asked", "I have successfully",
        "great job", excellent.
      trailer: a Co-Authored-By line naming Claude, Anthropic, GPT,
        OpenAI, Copilot, Gemini or an AI assistant; "Generated with"; the
        robot emoji U+1F916.
      hedge: "should work", "this ensures".
  - Not hits, counted as left: anything inside a fenced code block or an
    inline code span (code, commands and quoted program output must match
    the program, so they are not prose), and a filler or praise word that
    is also a string literal in the repository's source (for example
    "excellent" as a rating value); each literal is printed as a "left:"
    line naming where the value is defined, so the skill can confirm it.
  - --text - lints stdin as one text named <stdin> (commit messages from
    `git log --format=%B`, or pasted text); it counts as one file.
  - .prose-lint-ignore (in the current directory or --ignore) lists
    allowed words or phrases, one per line; a hit on one is not counted.

Usage: prose_check.py [paths...] [--files-from F|-] [--text -] [--ignore F]
Prints one "problem: file:line: class: match" line per hit and the counts;
exits 1 on any hit, or when zero files were read.
"""

import argparse
import os
import re
import sys

DASH = chr(0x2014)  # the em dash, spelled as a code point so this file carries none
ROBOT = chr(0x1F916)  # the robot emoji
PROSE_EXT = (".md", ".mdx", ".txt", ".rst", ".xcstrings", ".strings")
SKIP_DIRS = {
    ".git",
    "node_modules",
    "vendor",
    "dist",
    "build",
    ".venv",
    "venv",
    "__pycache__",
}
CLASSES = [
    (
        "filler",
        r"\bdelve[sd]?\b|\bdelving\b|\bleverag(?:e|es|ed|ing)\b|\brobust(?:ly|ness)?\b|\bseamless(?:ly)?\b"
        r"|\bcomprehensive(?:ly)?\b|\bstreamlin(?:e|es|ed|ing)\b|\bit(?:'|\u2019)?s worth noting\b"
        r"|\bin today(?:'|\u2019)s fast-paced\b|\bI hope this helps\b|\bgreat question\b|\bcertainly\b",
    ),
    (
        "praise",
        r"\bas requested\b|\bas you asked\b|\bI have successfully\b|\bgreat job\b|\bexcellent\b",
    ),
    (
        "trailer",
        r"Co-Authored-By:.*\b(?:Claude|Anthropic|GPT|OpenAI|Copilot|Gemini|AI assistant)\b"
        r"|\bGenerated with\b|" + ROBOT,
    ),
    ("hedge", r"\bshould work\b|\bthis ensures\b"),
]
CLASSES = [(n, re.compile(p, re.I)) for n, p in CLASSES]
TABLE_FILLER = re.compile(r"\|\s*" + DASH + r"\s*(?=\|)")
FENCE = re.compile(r"^\s*(```|~~~)")
INLINE_CODE = re.compile(r"`[^`]*`")
SOURCE_EXT = (".py", ".go", ".js", ".jsx", ".ts", ".tsx", ".java", ".kt", ".swift", ".rb", ".rs", ".cs", ".php")
STRING_LITERAL = re.compile(r"([\"'])([A-Za-z][A-Za-z_-]{1,30})\1")


def source_literals(root):
    """Map each short quoted string in the source under root (lowercased)
    to its first "path:line", so a word that is a program value (a rating,
    a status, an enum member) is not rewritten as if it were praise."""
    found = {}
    seen = 0
    for d, dirs, files in os.walk(root):
        dirs[:] = sorted(x for x in dirs if x not in SKIP_DIRS and not x.startswith("."))
        for f in sorted(files):
            if not f.endswith(SOURCE_EXT) or seen >= 2000:
                continue
            seen += 1
            path = os.path.join(d, f)
            try:
                text = open(path, encoding="utf-8").read()
            except (UnicodeDecodeError, OSError):
                continue
            for i, line in enumerate(text.splitlines(), 1):
                for m in STRING_LITERAL.finditer(line):
                    found.setdefault(m.group(2).lower(), f"{os.path.relpath(path, root)}:{i}")
    return found


def walk(path):
    if os.path.isfile(path):
        return [path]
    out = []
    for d, dirs, files in os.walk(path):
        dirs[:] = sorted(x for x in dirs if x not in SKIP_DIRS)
        for f in sorted(files):
            if f.endswith(PROSE_EXT) or f == "strings.xml":
                out.append(os.path.join(d, f))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("paths", nargs="*")
    ap.add_argument("--files-from", default=None)
    ap.add_argument("--ignore", default=".prose-lint-ignore")
    ap.add_argument("--text", default=None, choices=["-"])
    ap.add_argument("--source", default=".", help="directory whose source code defines literal values (default: .)")
    a = ap.parse_args()

    listed = []
    if a.files_from == "-":
        listed = sys.stdin.read().split("\n")
    elif a.files_from:
        if not os.path.isfile(a.files_from):
            print(
                f"prose-lint: no file list at {a.files_from}, nothing checked",
                file=sys.stderr,
            )
            return 1
        listed = open(a.files_from, encoding="utf-8").read().split("\n")
    listed = [p.strip() for p in listed if p.strip()]
    gone = [p for p in listed if not os.path.exists(p)]
    files = []
    prose = [
        p for p in listed
        if os.path.exists(p) and (os.path.isdir(p) or p.endswith(PROSE_EXT) or os.path.basename(p) == "strings.xml")
    ]
    for p in a.paths + prose:
        for f in walk(p):
            if f not in files:
                files.append(f)
    allowed = []
    if os.path.isfile(a.ignore):
        allowed = [
            w.strip().lower()
            for w in open(a.ignore, encoding="utf-8")
            if w.strip() and not w.startswith("#")
        ]

    texts = {}
    if a.text == "-" and a.files_from != "-":
        texts["<stdin>"] = sys.stdin.read()
        if texts["<stdin>"].strip():
            files.append("<stdin>")
    if not files:
        print(
            f"prose-lint: 0 files read ({len(a.paths)} paths, {len(listed)} listed, {len(gone)} gone), nothing checked",
            file=sys.stderr,
        )
        return 1
    literals = source_literals(a.source) if os.path.isdir(a.source) else {}
    counts = {"em dash": 0, "filler": 0, "praise": 0, "trailer": 0, "hedge": 0}
    left = lines = left_code = left_literal = 0
    hit_files = set()
    for f in files:
        try:
            text = texts[f] if f in texts else open(f, encoding="utf-8").read()
        except (UnicodeDecodeError, OSError):
            continue
        fenced = False
        for i, line in enumerate(text.splitlines(), 1):
            lines += 1
            if FENCE.match(line):
                fenced = not fenced
                continue
            if fenced:
                left_code += line.count(DASH) + sum(len(rx.findall(line)) for _, rx in CLASSES)
                continue
            spans = INLINE_CODE.findall(line)
            left_code += sum(sp.count(DASH) + sum(len(rx.findall(sp)) for _, rx in CLASSES) for sp in spans)
            line = INLINE_CODE.sub("``", line)
            if DASH in line:
                fill = len(TABLE_FILLER.findall(line))
                left += fill
                if line.count(DASH) > fill:
                    counts["em dash"] += 1
                    hit_files.add(f)
                    print(f"problem: {f}:{i}: em dash: {line.strip()[:100]}")
            for name, rx in CLASSES:
                for m in rx.finditer(line):
                    word = m.group(0).lower()
                    if word in allowed:
                        continue
                    if name in ("filler", "praise") and word in literals:
                        left_literal += 1
                        print(f"left: {f}:{i}: literal: {m.group(0)} (a value in {literals[word]}; confirm it is not praise)")
                        continue
                    counts[name] += 1
                    hit_files.add(f)
                    print(f"problem: {f}:{i}: {name}: {m.group(0)}")
    total = sum(counts.values())
    print(
        f"prose-lint: {len(files)} files, {lines} lines, {total} hits in {len(hit_files)} files "
        f"(em dash {counts['em dash']}, filler {counts['filler']}, praise {counts['praise']}, "
        f"trailer {counts['trailer']}, hedge {counts['hedge']}), {left} left (table filler), {len(gone)} listed files gone, "
        f"{left_code} left (code or quoted output), {left_literal} left (source literal)"
    )
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
