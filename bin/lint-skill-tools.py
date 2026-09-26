#!/usr/bin/env python3
"""lint-skill-tools: every command a skill tells the agent to run is granted.

A skill's body names commands in its Inputs, Steps and Commands sections
(backticked spans and ```bash fences). Its frontmatter `allowed-tools` grants
Bash(...) patterns. A command the body asks for but the frontmatter does not
grant either prompts on every run or is skipped, and a skipped verification
step is a gate that checks nothing.

For each command segment (split on | && || ;) whose program is a known CLI or
a script path:
  - a command bin/brg-guard blocks (push, tag, publish, deploy) is for the
    engineer to run; it is printed, not run, and is exempt;
  - a command listed in bin/lint-skill-tools.allow as
    "<skill>|<command prefix>|<reason>" is exempt (a line the skill prints
    for the engineer and never runs);
  - otherwise a Bash(...) grant must match it, or a bare Bash grant must
    exist. Grep and rg are also met by the Grep tool; cat and head at the
    start of a command by Read; ls and find at the start by Glob. A generic
    mention (`mkdir -p`) is met by a narrower grant (Bash(mkdir -p .bearing:*)).

Usage: lint-skill-tools.py [skills-dir] [allow-file]

Prints one line per ungranted command and a count; exits 1 on any finding,
and exits 1 when zero skills or zero commands were examined.
"""

import fnmatch
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GUARD = os.path.join(ROOT, "bin", "brg-guard")
ALLOW_FILE = os.path.join(ROOT, "bin", "lint-skill-tools.allow")
SECTIONS = {"Inputs", "Steps", "Commands"}

# Programs whose appearance at the start of a code span means "run this".
KNOWN = set(
    """
git make go gofmt golangci-lint govulncheck goose sqlc gorelease gopls
npm pnpm npx yarn node tsc vitest jest playwright eslint prettier
python python3 uv pytest ruff mypy pip alembic dbt sqlfluff airflow griffe
docker kubectl kustomize helm terraform tflint tfsec promtool k6 syft grype
gitleaks trivy osv-scanner flutter dart xcodebuild xcrun swift swiftlint
swiftformat xcodegen maestro ./gradlew gradle adb fastlane eas expo cargo
stat find tail head grep rg jq curl wc sort uniq diff sed awk cut tr cat ls
mkdir cp mv rm touch date printf printenv kill hyperfine lighthouse py-spy
clinic oasdiff claude glab gh bash sh zgrep
""".split()
)
GREP_TOOLS = {"grep", "rg", "zgrep"}
READ_TOOLS = {"cat", "head"}
GLOB_TOOLS = {"ls", "find"}
ROOT_VARS = ("${CLAUDE_PLUGIN_ROOT}", "$CLAUDE_PLUGIN_ROOT")


def load_allow():
    rows = []
    if not os.path.exists(ALLOW_FILE):
        return rows
    for raw in open(ALLOW_FILE, encoding="utf-8"):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = [p.strip() for p in line.split("|")]
        if len(parts) != 3 or not parts[2]:
            sys.exit(f"lint-tools: an allow row needs skill|prefix|reason: {line}")
        rows.append((parts[0], parts[1]))
    return rows


def frontmatter(text):
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    return (m.group(1), text[m.end() :]) if m else ("", text)


def allowed_tools(fm):
    m = re.search(r"^allowed-tools:\s*(.*)$", fm, re.M)
    if not m:
        return None
    tools, depth, cur = [], 0, ""
    for ch in m.group(1):  # split on commas outside parentheses
        depth += ch == "("
        depth -= ch == ")"
        if ch == "," and depth == 0:
            tools.append(cur.strip())
            cur = ""
        else:
            cur += ch
    if cur.strip():
        tools.append(cur.strip())
    return tools


def normalise(cmd):
    for v in ROOT_VARS:
        cmd = cmd.replace(v, "@ROOT")
    cmd = cmd.replace('"', "").replace("'", "")
    return re.sub(r"\s+", " ", cmd).strip()


def bash_patterns(tools):
    """Each Bash(...) grant as a glob over the normalised command."""
    out = []
    for t in tools:
        m = re.match(r"^Bash\((.*)\)$", t)
        if not m:
            continue
        p = normalise(m.group(1))
        if p.endswith(":*"):
            base = p[:-2].strip()
            out.append((base, [base, base + " *"]))
        else:
            out.append((p.rstrip(" *"), [p]))
    return out


def section_lines(body):
    cur = None
    for i, line in enumerate(body.split("\n"), 1):
        h = re.match(r"^## (.+?)\s*$", line)
        if h:
            cur = h.group(1)
            continue
        if cur in SECTIONS:
            yield i, line


def commands_in(body):
    """(lineno, command) for each candidate command in the scanned sections."""
    fence, lang = False, ""
    for i, line in section_lines(body):
        f = re.match(r"^\s*```(\S*)", line)
        if f:
            fence = not fence
            lang = f.group(1) if fence else ""
            continue
        if fence:
            s = line.strip()
            if lang in ("bash", "sh", "shell") and s and not s.startswith("#"):
                yield i, s
            continue
        for m in re.finditer(r"`([^`]+)`", line):
            # a span inside a double-quoted message is text the skill prints
            if line[: m.start()].count('"') % 2 == 1:
                continue
            yield i, m.group(1).strip()


def segments(cmd):
    """Split on | || && ; outside quotes; (segment, is-after-a-pipe-or-list)."""
    parts, cur, quote, i = [], "", "", 0
    while i < len(cmd):
        ch = cmd[i]
        if quote:
            quote = "" if ch == quote else quote
            cur += ch
        elif ch in "\"'":
            quote = ch
            cur += ch
        elif cmd.startswith(("||", "&&"), i):
            parts.append(cur)
            cur = ""
            i += 1
        elif ch in "|;":
            parts.append(cur)
            cur = ""
        else:
            cur += ch
        i += 1
    parts.append(cur)
    out = []
    for idx, p in enumerate(parts):
        p = p.strip()
        if p:
            # a <placeholder> ends the literal part of the command
            p = re.split(r"\s<", " " + p, maxsplit=1)[0].strip() or p
            out.append((p, idx > 0))
    return out


def program_of(seg):
    """The program a segment runs, or None when the span is not a command."""
    words = seg.split()
    while words and re.match(r"^[A-Z_][A-Z0-9_]*=", words[0]):
        words = words[1:]
    if not words:
        return None
    w = words[0]
    if w.startswith("@ROOT") or re.match(r"^(\./)?(bin|scripts)/", w):
        # a lone path names a file; it runs only with arguments after it
        if len(words) == 1:
            return None
    if (
        re.match(r"^(\./)?(bin|scripts)/[A-Za-z0-9_.-]+\.(sh|py|mjs|js)$", w)
        or w == "./gradlew"
    ):
        return w
    if w not in KNOWN:
        return None
    if len(words) == 1:
        return None  # a bare program name in prose is a name, not a command
    if w in ("bash", "sh") and not re.search(r"\.(sh|py)$|/bin/|install", words[1]):
        return None
    if seg.endswith("...") or words[1] in ("or", "and", "is", "as", "for"):
        return None
    return w


def granted(seg, prog, piped, tools, patterns):
    if "Bash" in tools:
        return True
    for base, globs in patterns:
        # seg + " _" stands for the arguments a <placeholder> held
        if any(fnmatch.fnmatchcase(c, g) for c in (seg, seg + " _") for g in globs):
            return True
        # a generic mention is met by a narrower grant of the same command
        if base.startswith(seg + " "):
            return True
    if prog in GREP_TOOLS and "Grep" in tools:
        return True
    if not piped and prog in READ_TOOLS and "Read" in tools:
        return True
    if not piped and prog in GLOB_TOOLS and "Glob" in tools:
        return True
    return False


def guard_blocks(cmd):
    try:
        r = subprocess.run(
            ["bash", GUARD, "command", cmd], capture_output=True, text=True, timeout=10
        )
    except subprocess.TimeoutExpired:
        return False
    return r.returncode == 2 and "cannot be read" not in (r.stdout + r.stderr)


def main():
    global ALLOW_FILE
    skills_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "skills")
    if len(sys.argv) > 2:
        ALLOW_FILE = sys.argv[2]
    allow = load_allow()
    used = set()
    if not os.path.isdir(skills_dir):
        print(f"lint-tools: no skills directory at {skills_dir}, nothing checked", file=sys.stderr)
        return 1
    names = sorted(
        d
        for d in os.listdir(skills_dir)
        if os.path.isfile(os.path.join(skills_dir, d, "SKILL.md"))
    )
    n_skills = n_cmds = n_exempt = 0
    findings = []
    for name in names:
        text = open(os.path.join(skills_dir, name, "SKILL.md"), encoding="utf-8").read()
        fm, body = frontmatter(text)
        tools = allowed_tools(fm)
        if tools is None:
            continue  # no allowed-tools: the normal permission flow applies
        n_skills += 1
        patterns = bash_patterns(tools)
        offset = fm.count("\n") + 3
        seen = set()
        for lineno, cmd in commands_in(body):
            for raw, piped in segments(cmd):
                seg = normalise(raw)
                prog = program_of(seg)
                if prog is None:
                    continue
                n_cmds += 1
                if granted(seg, prog, piped, tools, patterns):
                    continue
                hit = next(
                    (a for a in allow if a[0] == name and seg.startswith(a[1])), None
                )
                if hit:
                    used.add(hit)
                    n_exempt += 1
                    continue
                if guard_blocks(raw):
                    n_exempt += 1
                    continue
                key = " ".join(seg.split()[:2])
                if key in seen:
                    continue
                seen.add(key)
                findings.append(
                    f"skills/{name}/SKILL.md:{lineno + offset}: `{raw}` is not granted by allowed-tools"
                )
    for a in allow:
        if a not in used:
            findings.append(
                f"bin/lint-skill-tools.allow: stale row {a[0]}|{a[1]} (no command matches it)"
            )
    for f in findings:
        print(f)
    if n_skills == 0 or n_cmds == 0:
        print(
            f"lint-tools: {n_skills} skills, {n_cmds} commands examined, nothing checked",
            file=sys.stderr,
        )
        return 1
    print(
        f"lint-tools: {n_skills} skills, {n_cmds} commands examined, "
        f"{n_exempt} exempt (engineer-only), {len(findings)} problems"
    )
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
