#!/usr/bin/env bash
# tests/unit/doctor_trust.sh: doctor reports an untrusted workspace with the
# number of allow entries Claude Code is ignoring, and the fix. Trust on any
# ancestor folder counts, as Claude Code inherits it.
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
t_begin "untrusted with allow entries is a MISSING line in full doctor output"
printf '{"projects":{"%s":{"hasTrustDialogAccepted":false}}}\n' "$repo" > "$home/.claude.json"
out="$(cd "$repo" && HOME="$home" bash "$D" 2>&1)"
assert_contains "$out" "MISSING   workspace not trusted: Claude Code ignores 2 allow entries"
t_end
t_begin "untrusted with zero entries is optional, not a blocker"
repo0="$(tmpdir)"; git -C "$repo0" init -q -b main
printf '{"projects":{"%s":{"hasTrustDialogAccepted":false}}}\n' "$repo0" > "$home/.claude.json"
assert_exit 0 env HOME="$home" bash "$D" --trust-state "$repo0"
assert_eq "untrusted 0" "$T_OUT"
out="$(cd "$repo0" && HOME="$home" bash "$D" 2>&1)"
assert_contains "$out" "optional  workspace not trusted; no allow entries to ignore"
assert_not_contains "$out" "ignores 0 allow"
t_end
t_begin "trust is inherited from a trusted parent folder"
parent="$(dirname "$repo")"
printf '{"projects":{"%s":{"hasTrustDialogAccepted":true},"%s":{"hasTrustDialogAccepted":false}}}\n' "$parent" "$repo" > "$home/.claude.json"
assert_exit 0 env HOME="$home" bash "$D" --trust-state "$repo"
assert_eq "trusted" "$T_OUT" "parent true, child false"
printf '{"projects":{"%s":{"hasTrustDialogAccepted":true}}}\n' "$parent" > "$home/.claude.json"
assert_exit 0 env HOME="$home" bash "$D" --trust-state "$repo/sub/dir"
assert_eq "trusted" "$T_OUT" "parent true, no child entry"
printf '{"projects":{"%s":{"hasTrustDialogAccepted":true}}}\n' "$repo/sub" > "$home/.claude.json"
assert_exit 0 env HOME="$home" bash "$D" --trust-state "$repo"
assert_eq "untrusted 2" "$T_OUT" "a trusted child does not trust its parent"
t_end
t_summary
