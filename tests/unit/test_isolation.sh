#!/usr/bin/env bash
# tests/unit/test_isolation.sh: the test library gives every test a config
# folder of its own, so a Stop gate block or a skill rerun in a test never
# lands in the developer's ~/.config/bearing/learnings.jsonl, which real
# sessions read back as advice. bash 3.2 safe.
set -u
. "$(dirname "$0")/../lib/assert.sh"

t_begin "every test starts with its own empty config folder"
case "$XDG_CONFIG_HOME" in ("$T_KITS"/*) own=1 ;; (*) own=0 ;; esac
assert_eq 1 "$own" "XDG_CONFIG_HOME is under the test's temp folder"
assert_eq "" "$(ls -A "$XDG_CONFIG_HOME")" "and starts empty"
assert_eq "" "${BEARING_ENV:-}" "BEARING_ENV from the caller is unset"
t_end

t_begin "a Stop gate block logs to the test's config, not the developer's"
mkdir -p "$XDG_CONFIG_HOME/bearing"; echo BEARING_LEARNING=on > "$XDG_CONFIG_HOME/bearing/bearing.env"
repo="$(tmpdir)"
git -C "$repo" init -q -b main
git -C "$repo" config user.email t@example.com; git -C "$repo" config user.name t
printf '.bearing/state/\n' > "$repo/.gitignore"
printf 'check:\n\t@touch .bearing/state/.check-passed\n' > "$repo/Makefile"
git -C "$repo" add .gitignore Makefile; git -C "$repo" commit -q -m "chore: init"
mkdir -p "$repo/.bearing/state"
touch -t 202001010000 "$repo/.bearing/state/.check-passed"
: > "$repo/.bearing/state/.session-s1"; touch -t 202001010000 "$repo/.bearing/state/.session-s1"
printf 'x\n' > "$repo/fresh.txt"
assert_exit 2 bash -c "cd '$repo' && bash '$GUARD' stop-gate --id s1"
assert_contains "$(cat "$XDG_CONFIG_HOME/bearing/learnings.jsonl" 2>/dev/null)" '"skill":"stop-gate"' "the block is logged in the test's folder"
t_end

t_summary
