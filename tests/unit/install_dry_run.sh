#!/usr/bin/env bash
# tests/unit/install_dry_run.sh: install.sh never touches the machine under
# --dry-run. Runs with a fake HOME, no XDG_CONFIG_HOME, and stub claude, node
# and npx binaries in front of PATH so the standard profile gets past its
# prerequisite checks without a real Claude CLI. Asserts the dry-run summary,
# the --no-claude harness instruction, the uninstall counts, and that nothing
# appears under the fake HOME (no env file, no ~/.claude, no gstack clone).
set -u
. "$(dirname "$0")/../lib/assert.sh"
INSTALL="$KIT/install.sh"

fh="$(tmpdir)"
stubs="$(tmpdir)"
cat > "$stubs/claude" <<'EOF'
#!/bin/sh
case "$1" in
  --version) echo "2.1.0 (Claude Code)";;
  plugin) exit 0;;
  *) exit 0;;
esac
EOF
cat > "$stubs/node" <<'EOF'
#!/bin/sh
echo "v22.0.0"
EOF
cp "$stubs/node" "$stubs/npx"
chmod +x "$stubs/claude" "$stubs/node" "$stubs/npx"

# under_fake <install args...>: run install.sh with the fake HOME and stubs.
under_fake() { env -u XDG_CONFIG_HOME HOME="$fh" PATH="$stubs:$PATH" bash "$INSTALL" "$@"; }
# tree <dir>: every path under the directory, sorted, one per line.
tree() { find "$1" -mindepth 1 2>/dev/null | sort; }
ENVF="$fh/.config/bearing/bearing.env"
runs=0

t_begin "--dry-run: standard profile prints a summary and changes nothing"
assert_exit 0 under_fake --dry-run; runs=$((runs+1))
assert_contains "$T_OUT" "== prerequisites (dry run: nothing is changed) (profile standard)"
assert_contains "$T_OUT" "would run  claude plugin marketplace add"
assert_contains "$T_OUT" "would run  claude plugin install bearing@bearing"
assert_contains "$T_OUT" "would run  claude plugin install bearing-backend@bearing"
assert_contains "$T_OUT" "would run  claude plugin install bearing-apps@bearing"
assert_contains "$T_OUT" "would run  claude plugin install bearing-genai@bearing"
assert_contains "$T_OUT" "would run  claude plugin install superpowers@claude-plugins-official"
# The pins come from pinned-packs.txt; the dry run names the same ones.
pins="$KIT/plugins/bearing/bin/pinned-packs.txt"
gsha="$(awk -F'|' '$1=="clone" && $2=="garrytan/gstack" {print $3}' "$pins")"
gsdv="$(awk -F'|' '$1=="npm" && $2=="@opengsd/gsd-core" {print $3}' "$pins")"
_t_count; printf '%s' "$gsha" | grep -Eq '^[0-9a-f]{40}$' || _t_fail "gstack is not pinned to a full commit in pinned-packs.txt: '$gsha'"
_t_count; printf '%s' "$gsdv" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || _t_fail "GSD Core is not pinned to an exact version in pinned-packs.txt: '$gsdv'"
assert_contains "$T_OUT" "would run  git_fetch_at https://github.com/garrytan/gstack.git $gsha $fh/.claude/skills/gstack"
assert_contains "$T_OUT" "would run  npx --yes @opengsd/gsd-core@$gsdv --global --claude"
assert_not_contains "$T_OUT" "@latest" "no unpinned npm fetch"
assert_contains "$T_OUT" "would copy $KIT/plugins/bearing/templates/user/bearing.env -> $ENVF (mode 600)"
assert_contains "$T_OUT" "would copy $KIT/plugins/bearing/templates/user/CLAUDE.md -> ~/.claude/CLAUDE.md"
assert_contains "$T_OUT" "would run  bash $KIT/plugins/bearing/bin/brg-doctor"
assert_contains "$T_OUT" "install.sh: 11 installed, 0 already present, 1 skipped, 0 failed (dry run: nothing is changed)"
assert_contains "$T_OUT" "Restart Claude Code to load new plugins."
assert_eq "" "$(tree "$fh")" "nothing created under the fake HOME"
_t_count; [ -e "$ENVF" ] && _t_fail "env file was created under --dry-run: $ENVF"
t_end

t_begin "--dry-run: standard installs impeccable at its pin; minimal and --skip-impeccable do not"
isha="$(awk -F'|' '$1=="cli" && $2=="pbakaus/impeccable" {print $3}' "$pins")"
skv="$(awk -F'|' '$1=="npm" && $2=="skills" {print $3}' "$pins")"
_t_count; printf '%s' "$isha" | grep -Eq '^[0-9a-f]{40}$' || _t_fail "impeccable is not pinned to a full commit: '$isha'"
assert_exit 0 under_fake --dry-run
assert_contains "$T_OUT" "would run  npx --yes skills@$skv add pbakaus/impeccable#$isha -a claude-code -g -y"
assert_exit 0 under_fake --dry-run --profile minimal
assert_not_contains "$T_OUT" "pbakaus/impeccable"
assert_exit 0 under_fake --dry-run --skip-impeccable
assert_contains "$T_OUT" "skipped    impeccable"
t_end

t_begin "--skip-impeccable holds on --profile full: no impeccable install, and brg-install-packs is told"
assert_exit 0 under_fake --dry-run --profile full --skip-impeccable; runs=$((runs+1))
assert_contains "$T_OUT" "would run  bash $KIT/plugins/bearing/bin/brg-install-packs --skip-impeccable"
assert_not_contains "$T_OUT" "add pbakaus/impeccable"
# brg-install-packs itself skips the row: a stub npx records every call.
calls="$(tmpdir)/calls"; sh_stubs="$(tmpdir)"
printf '#!/bin/sh\necho "$*" >> "%s"\nexit 0\n' "$calls" > "$sh_stubs/npx"; chmod +x "$sh_stubs/npx"
env -u XDG_CONFIG_HOME HOME="$fh" PATH="$sh_stubs:$stubs:$PATH" bash "$KIT/plugins/bearing/bin/brg-install-packs" --skip-official --skip-playwright --skip-pinned --skip-impeccable > "$sh_stubs/out" 2>&1
T_OUT="$(cat "$sh_stubs/out")"
assert_contains "$T_OUT" "skipped    pbakaus/impeccable (impeccable; --skip-impeccable)"
_t_count; grep -q 'pbakaus/impeccable' "$calls" && _t_fail "brg-install-packs ran the impeccable install under --skip-impeccable"
_t_count; grep -q 'differential-review\|trailofbits' "$calls" || _t_fail "the stub npx saw no other cli row, so the check examined nothing"
t_end

t_begin "impeccable already installed under ~/.agents is present, not reinstalled"
ah="$(tmpdir)"; mkdir -p "$ah/.agents/skills/impeccable"
assert_exit 0 env -u XDG_CONFIG_HOME HOME="$ah" PATH="$stubs:$PATH" bash "$INSTALL" --dry-run
assert_contains "$T_OUT" "present    impeccable"
assert_not_contains "$T_OUT" "add pbakaus/impeccable"
t_end

t_begin "a pin file without the impeccable row fails with a message"
kit2="$(tmpdir)"; mkdir -p "$kit2/plugins"; cp "$INSTALL" "$kit2/install.sh"; cp -R "$KIT/plugins/bearing" "$kit2/plugins/bearing"
grep -v 'pbakaus/impeccable' "$KIT/plugins/bearing/bin/pinned-packs.txt" > "$kit2/plugins/bearing/bin/pinned-packs.txt"
assert_exit 1 env -u XDG_CONFIG_HOME HOME="$fh" PATH="$stubs:$PATH" bash "$kit2/install.sh" --dry-run
assert_contains "$T_OUT" "FAILED     impeccable: no cli|pbakaus/impeccable or npm|skills row"
t_end

t_begin "--dry-run --profile full: packs would run, still nothing changes"
assert_exit 0 under_fake --dry-run --profile full; runs=$((runs+1))
assert_contains "$T_OUT" "would run  bash $KIT/plugins/bearing/bin/brg-install-packs"
assert_contains "$T_OUT" "(dry run: nothing is changed)"
assert_eq "" "$(tree "$fh")" "nothing created under the fake HOME"
t_end

t_begin "--no-claude --dry-run --profile minimal prints the harness instruction"
assert_exit 0 under_fake --no-claude --dry-run --profile minimal; runs=$((runs+1))
assert_contains "$T_OUT" "(profile minimal)"
assert_contains "$T_OUT" "skipped    claude plugin marketplace and plugin install (--no-claude)"
assert_contains "$T_OUT" "skipped    superpowers, gstack, GSD Core, impeccable (--no-claude)"
assert_contains "$T_OUT" "skipped    ~/.claude/CLAUDE.md (--no-claude)"
assert_contains "$T_OUT" "skipped    brg-doctor (checks the Claude Code install; --no-claude)"
assert_contains "$T_OUT" "next: in each repository run  bash $KIT/plugins/bearing/bin/brg-harness <cursor|codex|gemini|copilot|opencode|windsurf|cline|zed|kiro|all> --dir <repo>"
assert_contains "$T_OUT" "(dry run: nothing is changed)"
assert_not_contains "$T_OUT" "Restart Claude Code" "no restart note without claude"
assert_eq "" "$(tree "$fh")" "nothing created under the fake HOME"
t_end

t_begin "--dry-run --uninstall on an empty machine: counts, no prompt, no change"
assert_exit 0 under_fake --dry-run --uninstall; runs=$((runs+1))
assert_contains "$T_OUT" "== uninstall (dry run: nothing is changed)"
assert_contains "$T_OUT" "would ask  Remove the Bearing plugins (bearing, bearing-backend, bearing-apps, bearing-genai) and their marketplace from Claude Code?"
assert_contains "$T_OUT" "absent     plugin bearing@bearing"
assert_contains "$T_OUT" "absent     plugin bearing-backend@bearing"
assert_contains "$T_OUT" "absent     plugin bearing-apps@bearing"
assert_contains "$T_OUT" "absent     plugin bearing-genai@bearing"
assert_contains "$T_OUT" "absent     marketplace bearing"
assert_contains "$T_OUT" "absent     $ENVF"
assert_contains "$T_OUT" "absent     ~/.claude/CLAUDE.md"
assert_contains "$T_OUT" "install.sh --uninstall: 0 removed, 0 kept, 0 failed (dry run: nothing is changed)"
assert_eq "" "$(tree "$fh")" "nothing created under the fake HOME"
t_end

t_begin "--dry-run --uninstall with an env file and an edited CLAUDE.md keeps both"
mkdir -p "$fh/.config/bearing" "$fh/.claude"
printf 'BEARING_TRACKER=none\nBEARING_TRACKER_TOKEN=do-not-print\n' > "$ENVF"
printf '# my own notes\n' > "$fh/.claude/CLAUDE.md"
before="$(tree "$fh")"
assert_exit 0 under_fake --dry-run --uninstall; runs=$((runs+1))
assert_contains "$T_OUT" "would ask  Also delete $ENVF (holds your tracker credentials)?"
assert_contains "$T_OUT" "would run  rm -f $ENVF"
assert_contains "$T_OUT" "kept       ~/.claude/CLAUDE.md (edited by you)"
assert_contains "$T_OUT" "install.sh --uninstall: 1 removed, 1 kept, 0 failed (dry run: nothing is changed)"
assert_not_contains "$T_OUT" "do-not-print" "the env file's contents are never printed"
assert_file "$ENVF"
assert_eq "$before" "$(tree "$fh")" "the fake HOME is unchanged after a dry uninstall"
t_end

t_begin "bad options are refused before anything runs"
assert_exit 2 under_fake --profile huge --dry-run; runs=$((runs+1))
assert_contains "$T_OUT" "--profile must be minimal, standard or full (got 'huge')"
assert_exit 2 under_fake --bogus; runs=$((runs+1))
assert_contains "$T_OUT" "unknown option: --bogus"
assert_exit 0 under_fake --help; runs=$((runs+1))
assert_contains "$T_OUT" "bash install.sh [--profile minimal|standard|full] [--dry-run] [--no-claude]"
t_end

t_begin "node only under nvm (not on PATH): the newest nvm version is used, not called missing"
nh="$(tmpdir)"; bare="$(tmpdir)"
for v in v20.11.0 v22.3.0 v9.9.9; do
  mkdir -p "$nh/.nvm/versions/node/$v/bin"
  printf '#!/bin/sh\necho %s\n' "$v" > "$nh/.nvm/versions/node/$v/bin/node"
  cp "$nh/.nvm/versions/node/$v/bin/node" "$nh/.nvm/versions/node/$v/bin/npx"
  chmod +x "$nh/.nvm/versions/node/$v/bin/node" "$nh/.nvm/versions/node/$v/bin/npx"
done
# A PATH holding only the tools install.sh needs and the claude stub, so a
# node installed on this machine cannot hide the lookup.
for t in bash sh env git awk sed grep sort tail head tr cat ls mkdir dirname basename find cut wc uname date cp mv rm chmod python3 jq make; do
  w="$(command -v "$t" 2>/dev/null)" && ln -s "$w" "$bare/$t"
done
ln -s "$stubs/claude" "$bare/claude"
assert_exit 0 env -u XDG_CONFIG_HOME -u NVM_DIR HOME="$nh" PATH="$bare" bash "$INSTALL" --dry-run; runs=$((runs+1))
assert_contains "$T_OUT" "node: not on PATH; using $nh/.nvm/versions/node/v22.3.0/bin"
assert_contains "$T_OUT" "node v22.3.0"
assert_not_contains "$T_OUT" "missing: node"
t_end

echo "install_dry_run: $runs install.sh runs, 0 files touched under the fake HOME"
t_summary
