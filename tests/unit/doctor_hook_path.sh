#!/usr/bin/env bash
# tests/unit/doctor_hook_path.sh: brg-doctor resolves the tools the hooks
# need (BRG_HOOK_TOOLS in hooks/scripts/lib.sh) on the hook PATH (the PATH
# line in the same file), not on the shell's PATH, and prints the fix for one
# that is missing. A hook_kit copy sets the hook PATH. bash 3.2 safe.
set -u
. "$(dirname "$0")/../lib/assert.sh"
repo="$(tmpdir)"; home="$(tmpdir)"
git -C "$repo" init -q -b main

t_begin "every hook tool found on the hook PATH passes, named with its path"
k="$(hook_kit "$(minimal_path jq python3 git bash)")"
assert_eq 1 "$([ -f "$k/bin/brg-doctor" ] && echo 1)" "hook_kit made a kit"
out="$(cd "$repo" && HOME="$home" BEARING_PROFILE=minimal bash "$k/bin/brg-doctor" 2>&1)"
n=0
for t in jq python3 git bash; do
  assert_contains "$out" "ok        $t on the hook PATH ("
  n=$((n+1))
done
assert_eq 4 "$n" "hook tools checked"
assert_contains "$out" "hook PATH: 4 tools checked"
t_end

t_begin "jq missing from the hook PATH is MISSING with the fix, though the shell finds it"
k="$(hook_kit "$(minimal_path python3 git bash)")"
out="$(cd "$repo" && HOME="$home" BEARING_PROFILE=minimal bash "$k/bin/brg-doctor" 2>&1)"; rc=$?
assert_contains "$out" "MISSING   jq not found on the hook PATH ("
assert_contains "$out" "ln -s"
assert_contains "$out" "ok        git on the hook PATH ("
assert_eq 1 "$rc" "doctor exits 1"
t_end

t_begin "an unreadable hook PATH is MISSING, never a pass on zero tools"
k="$(hook_kit /nowhere)"
replace_in "$k/hooks/scripts/lib.sh" "BRG_HOOK_TOOLS='jq python3 git bash'" "" >/dev/null
out="$(cd "$repo" && HOME="$home" BEARING_PROFILE=minimal bash "$k/bin/brg-doctor" 2>&1)"
assert_contains "$out" "MISSING   hook PATH or hook tools unreadable"
t_end
t_summary
