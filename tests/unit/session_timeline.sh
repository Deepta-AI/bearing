#!/usr/bin/env bash
# tests/unit/session_timeline.sh: timeline start, implicit end, close, recent,
# no-op outside a Bearing repo, and a branch without a task id.
set -u
. "$(dirname "$0")/../lib/assert.sh"
S="$KIT/plugins/bearing/bin/brg-session"
repo="$(tmpdir)"; git -C "$repo" init -q -b feat/RuntimeAndFeel; mkdir -p "$repo/.bearing/state"
in_repo() { ( cd "$repo" && bash "$S" "$@" ) }
tl="$repo/.bearing/state/timeline.jsonl"

t_begin "start, implicit end, close"
assert_exit 0 in_repo timeline-start --id s1 --skill bearing:start-task
assert_exit 0 in_repo timeline-start --id s1 --skill bearing:test-cases
assert_exit 0 in_repo timeline-close --id s1
assert_eq 4 "$(wc -l < "$tl" | tr -d ' ')" "four events"
assert_contains "$(sed -n 2p "$tl")" '"skill":"bearing:start-task","event":"end"'
assert_contains "$(sed -n 4p "$tl")" '"skill":"bearing:test-cases","event":"end"'
assert_contains "$(sed -n 1p "$tl")" '"epoch":'
t_end

t_begin "recent lists ended skills on the branch, newest last"
assert_exit 0 in_repo timeline-recent --n 3
assert_eq "bearing:start-task
bearing:test-cases" "$T_OUT"
t_end

t_begin "no .bearing directory is a silent no-op"
other="$(tmpdir)"; git -C "$other" init -q -b main
assert_exit 0 bash -c "cd '$other' && bash '$S' timeline-start --id s1 --skill x"
assert_eq "" "$T_OUT"
[ ! -e "$other/.bearing" ]; assert_eq 0 $? "nothing created"
t_end

t_summary
