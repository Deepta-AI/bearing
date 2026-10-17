#!/usr/bin/env bash
# tests/unit/changed_files.sh: brg-changed lists changed files rename-safe and
# space-safe; stop-gate prefers make check-changed and falls back to make check.
set -u
. "$(dirname "$0")/../lib/assert.sh"
CHANGED="$KIT/plugins/bearing/bin/brg-changed"

repo="$(tmpdir)"
git -C "$repo" init -q -b main
printf '.bearing/state/\n' > "$repo/.gitignore"
printf 'a\n' > "$repo/old name.txt"; printf 'b\n' > "$repo/keep.txt"
git -C "$repo" add -A; git -C "$repo" -c user.email=t@example.com -c user.name=t commit -q -m init

t_begin "renamed, spaced, untracked and modified files"
git -C "$repo" mv "old name.txt" "new name.txt"
printf 'c\n' > "$repo/fresh.txt"; printf 'b2\n' > "$repo/keep.txt"
assert_exit 0 bash "$CHANGED" --root "$repo"
assert_contains "$T_OUT" "new name.txt"
assert_not_contains "$T_OUT" "old name.txt"
assert_contains "$T_OUT" "fresh.txt"
assert_contains "$T_OUT" "keep.txt"
t_end

t_begin "since a fresh marker nothing is listed"
mkdir -p "$repo/.bearing/state"; sleep 1; touch "$repo/.bearing/state/.check-passed"
assert_exit 0 bash "$CHANGED" --root "$repo" --since "$repo/.bearing/state/.check-passed"
assert_eq "" "$T_OUT"
t_end

sid=s1
in_repo() { ( cd "$repo" && bash "$GUARD" "$@" ) }
t_begin "stop-gate asks for check-changed when the target exists"
touch -t 202001010000 "$repo/.bearing/state/.check-passed"
: > "$repo/.bearing/state/.session-$sid"; touch -t 202001010000 "$repo/.bearing/state/.session-$sid"
printf 'check:\n\t@touch .bearing/state/.check-passed\ncheck-changed:\n\t@true\n' > "$repo/Makefile"
printf 'd\n' > "$repo/fresh.txt"
assert_exit 2 in_repo stop-gate --id "$sid"
assert_contains "$T_OUT" "Run make check-changed"
t_end

t_begin "a check-changed pass satisfies the gate"
sleep 1; touch "$repo/.bearing/state/.check-changed-passed"
assert_exit 0 in_repo stop-gate --id "$sid"
t_end

t_begin "without check-changed the old message stands"
printf 'check:\n\t@touch .bearing/state/.check-passed\n' > "$repo/Makefile"
rm -f "$repo/.bearing/state/.check-changed-passed"; sleep 1; printf 'e\n' > "$repo/fresh.txt"
assert_exit 2 in_repo stop-gate --id "$sid"
assert_contains "$T_OUT" "Run make check and fix what fails"
t_end

t_summary
