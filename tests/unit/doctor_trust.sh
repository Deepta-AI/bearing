#!/usr/bin/env bash
# tests/unit/doctor_trust.sh: doctor reports an untrusted workspace with the
# number of allow entries Claude Code is ignoring, and the fix.
set -u
. "$(dirname "$0")/../lib/assert.sh"
D="$KIT/plugins/bearing/bin/brg-doctor"
repo="$(tmpdir)"; home="$(tmpdir)"
git -C "$repo" init -q -b main; mkdir -p "$repo/.claude"
printf '{"permissions":{"allow":["Bash(make:*)","Bash(git status:*)"]}}\n' > "$repo/.claude/settings.json"
printf '{"projects":{"%s":{"hasTrustDialogAccepted":false}}}\n' "$repo" > "$home/.claude.json"
t_begin "untrusted"
assert_exit 0 env HOME="$home" bash "$D" --trust-state "$repo"
assert_eq "untrusted 2" "$T_OUT"
t_end
t_begin "trusted"
printf '{"projects":{"%s":{"hasTrustDialogAccepted":true}}}\n' "$repo" > "$home/.claude.json"
assert_exit 0 env HOME="$home" bash "$D" --trust-state "$repo"
assert_eq "trusted" "$T_OUT"
t_end
t_begin "no claude.json"
rm -f "$home/.claude.json"
assert_exit 0 env HOME="$home" bash "$D" --trust-state "$repo"
assert_eq "unknown" "$T_OUT"
t_end
t_summary
