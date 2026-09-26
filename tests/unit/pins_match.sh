#!/usr/bin/env bash
# tests/unit/pins_match.sh: every external fetch Bearing makes is pinned, and
# pinned in one place (plugins/bearing/bin/pinned-packs.txt).
#
# 1. Every row of pinned-packs.txt is well formed: git rows (skill, plugin,
#    cli, clone) pin a full commit, npm and pypi rows an exact version.
# 2. Every npx, pnpm dlx, uvx or uv --with fetch in what the plugins run
#    (install.sh, plugins/*/bin, each skill's SKILL.md, references/, scripts/
#    and the two templates a skill runs itself) names an exact version, and
#    that version is the one pinned-packs.txt holds. `npx expo` is exempt: it
#    runs the repository's own locked expo.
# 3. README.md names every npm, pypi and clone pin.
# 4. brg-install-packs and brg-harness call npx with the pinned skills CLI and
#    each repository at its commit (stub npx, fake HOME: nothing is fetched).
# bash 3.2 safe.
set -u
. "$(dirname "$0")/../lib/assert.sh"
PINS="$KIT/plugins/bearing/bin/pinned-packs.txt"

t_begin "pinned-packs.txt rows are well formed and fetches match them"
T_IN="$(cat <<'PY'
import glob, os, re, sys
kit = sys.argv[1]
os.chdir(kit)
rows, bad = [], []
for n, line in enumerate(open("plugins/bearing/bin/pinned-packs.txt", encoding="utf-8"), 1):
    line = line.rstrip("\n")
    if not line.strip() or line.lstrip().startswith("#"):
        continue
    f = line.split("|")
    if len(f) != 6:
        bad.append(f"pinned-packs.txt:{n}: {len(f)} fields, want 6")
        continue
    kind, src, pin = f[0], f[1], f[2]
    if kind in ("skill", "plugin", "cli", "clone"):
        if not re.fullmatch(r"[0-9a-f]{40}", pin):
            bad.append(f"pinned-packs.txt:{n}: {kind} {src} is not pinned to a full commit")
    elif kind in ("npm", "pypi"):
        if not re.fullmatch(r"\d+\.\d+\.\d+", pin):
            bad.append(f"pinned-packs.txt:{n}: {kind} {src} is not pinned to an exact version")
    else:
        bad.append(f"pinned-packs.txt:{n}: unknown kind {kind}")
    rows.append((kind, src, pin))
npm = {s: p for k, s, p in rows if k == "npm"}
pypi = {s.lower(): p for k, s, p in rows if k == "pypi"}

files = ["install.sh"] + sorted(glob.glob("plugins/*/bin/brg-*"))
for skill in sorted(glob.glob("plugins/*/skills/*/")):
    files.append(skill + "SKILL.md")
    for sub in ("references", "scripts"):
        files += sorted(p for p in glob.glob(f"{skill}{sub}/**/*", recursive=True)
                        if os.path.isfile(p) and "__pycache__" not in p)
files += ["plugins/bearing/skills/openapi-spec/templates/api-conformance.mk",
          "plugins/bearing/skills/mcp-server/templates/server-typescript.md",
          "plugins/bearing/skills/mcp-server/templates/server-python.md"]
EXEMPT_NPX = {"expo"}
# English words after npx or uvx in prose ("npx not found", "its npx installer").
PROSE = {"not", "installer", "is", "and", "or", "to", "the", "found", "call", "calls", "fetch", "tool"}
VER = r"(@[0-9A-Za-z.$<>{}_-]+)?"
checked = 0
for p in files:
    if not os.path.isfile(p):
        bad.append(f"{p}: listed for the scan but missing")
        continue
    text = re.sub(r"\s+", " ", open(p, encoding="utf-8", errors="replace").read())
    for m in re.finditer(r"\b(?:npx(?: --yes)?|pnpm dlx|bunx) (@?[a-z0-9][\w./-]*)" + VER, text):
        name, ver = m.group(1), (m.group(2) or "")[1:]
        if name in EXEMPT_NPX or name in PROSE:
            continue
        checked += 1
        if not ver:
            bad.append(f"{p}: unpinned npm fetch: {m.group(0)}")
        elif "$" in ver or "<" in ver:
            continue
        elif npm.get(name) != ver:
            bad.append(f"{p}: {name}@{ver} does not match pinned-packs.txt ({npm.get(name, 'no row')})")
    for m in re.finditer(r"\buvx ([a-z0-9][\w.-]*)(@[\w.]+)?", text):
        name, ver = m.group(1).lower(), (m.group(2) or "")[1:]
        if name in PROSE:
            continue
        checked += 1
        if pypi.get(name) != ver:
            bad.append(f"{p}: uvx {name}@{ver or '?'} does not match pinned-packs.txt ({pypi.get(name, 'no row')})")
    for m in re.finditer(r"--with ([A-Za-z0-9][\w.-]*)(==[\w.]+)?", text):
        checked += 1
        name, ver = m.group(1).lower(), (m.group(2) or "")[2:]
        if pypi.get(name) != ver:
            bad.append(f"{p}: --with {name}=={ver or '?'} does not match pinned-packs.txt ({pypi.get(name, 'no row')})")
    if re.search(r"(npx|dlx|bunx|uvx)[^`\n]*@latest", text):
        bad.append(f"{p}: @latest in a fetch")

readme = open("README.md", encoding="utf-8").read()
for k, s, p in rows:
    if k in ("npm", "pypi", "clone") and p not in readme:
        bad.append(f"README.md does not name the {k} pin {s} {p}")

for b in bad:
    print(b)
if not rows or checked == 0:
    print(f"nothing checked: {len(rows)} pins, {checked} fetches")
    sys.exit(1)
print(f"pins: {len(rows)} rows, {checked} fetches in {len(files)} files, {len(bad)} problems")
sys.exit(1 if bad else 0)
PY
)"
t_run python3 - "$KIT"; T_IN=''
_t_count; [ "$T_RC" -eq 0 ] || _t_fail "$T_OUT"
assert_contains "$T_OUT" ", 0 problems"
echo "$T_OUT" | tail -1
t_end

# Stub npx and claude that record their arguments; a fake HOME.
fh="$(tmpdir)"; stubs="$(tmpdir)"; log="$fh/calls.log"
printf '#!/bin/sh\necho "npx $*" >> "%s"\nexit 0\n' "$log" > "$stubs/npx"
printf '#!/bin/sh\necho "claude $*" >> "%s"\nexit 0\n' "$log" > "$stubs/claude"
chmod +x "$stubs/npx" "$stubs/claude"
skills_v="$(awk -F'|' '$1=="npm" && $2=="skills" {print $3}' "$PINS")"
pw_v="$(awk -F'|' '$1=="npm" && $2=="@playwright/cli" {print $3}' "$PINS")"
cli_rows="$(grep -c '^cli|' "$PINS")"

t_begin "brg-install-packs runs the pinned skills CLI with each repository at its commit"
: > "$log"
assert_exit 0 env HOME="$fh" PATH="$stubs:$PATH" bash "$KIT/plugins/bearing/bin/brg-install-packs" --skip-official --skip-pinned
assert_eq "$cli_rows" "$(grep -c "^npx --yes skills@$skills_v add [^ ]*#[0-9a-f]\{40\} -a claude-code -g -y" "$log")" "one pinned skills CLI call per cli row"
assert_eq "0" "$(grep -c "^npx --yes skills add" "$log")" "no unpinned skills CLI call"
assert_contains "$(cat "$log")" "npx --yes @playwright/cli@$pw_v install --skills -g"
assert_contains "$(cat "$log")" "npx --yes skills@$skills_v add vercel-labs/agent-skills#"
t_end

t_begin "brg-harness installs the kit skills at the release tag with the pinned skills CLI"
: > "$log"; repo="$(tmpdir)"; git -C "$repo" init -q
version="$(bash "$KIT/plugins/bearing/bin/brg-kit-paths" --version)"
assert_exit 0 env HOME="$fh" PATH="$stubs:$PATH" bash "$KIT/plugins/bearing/bin/brg-harness" cursor --dir "$repo" --kit-url https://example.test/bearing.git
assert_contains "$(cat "$log")" "npx --yes skills@$skills_v add https://example.test/bearing.git#v$version --all -a cursor -g -y"
: > "$log"
assert_exit 0 env HOME="$fh" PATH="$stubs:$PATH" bash "$KIT/plugins/bearing/bin/brg-harness" cursor --dir "$repo" --kit-url https://example.test/bearing.git --kit-ref 0123abc
assert_contains "$(cat "$log")" "add https://example.test/bearing.git#0123abc --all"
t_end

t_summary
