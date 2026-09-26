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
# The checker is its own file: bash 3.2 cannot parse a heredoc inside $(...).
t_run python3 "$(dirname "$0")/pins_match.py" "$KIT"
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
