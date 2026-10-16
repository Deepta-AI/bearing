#!/usr/bin/env bash
# tests/unit/session_resume.sh: next step from the timeline and the resume
# block, with and without a task id.
set -u
. "$(dirname "$0")/../lib/assert.sh"
S="$KIT/plugins/bearing/bin/brg-session"
repo="$(tmpdir)"; git -C "$repo" init -q -b main
git -C "$repo" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init
git -C "$repo" checkout -q -b bugfix/TASK-9-crash; mkdir -p "$repo/.bearing/state"
in_repo() { ( cd "$repo" && bash "$S" "$@" ) }
first="$(awk -F'\t' '$1=="bugfix" && $2==1 {print $3}' "$KIT/plugins/bearing/bin/flow-steps.tsv")"
second="$(awk -F'\t' '$1=="bugfix" && $2==2 {print $3}' "$KIT/plugins/bearing/bin/flow-steps.tsv")"

t_begin "nothing ran: next is the first bugfix step"
assert_exit 0 in_repo next-step
assert_eq "$first" "$T_OUT"
t_end

t_begin "after the first step, next is the second"
in_repo timeline-start --id s --skill "bearing:$first"; in_repo timeline-close --id s
assert_exit 0 in_repo next-step
assert_eq "$second" "$T_OUT"
t_end

t_begin "resume block"
assert_exit 0 in_repo resume --source startup
assert_contains "$T_OUT" "Resume TASK-9: last ran bearing:$first. Next: $second."
assert_eq 1 "$([ "$(printf '%s\n' "$T_OUT" | wc -l)" -le 40 ] && echo 1 || echo 0)" "at most 40 lines"
t_end

t_begin "branch without an id"
git -C "$repo" checkout -q -b feat/RuntimeAndFeel
assert_exit 0 in_repo resume --source startup
assert_contains "$T_OUT" "Resume this branch: last ran nothing yet."
assert_not_contains "$T_OUT" "Resume :"
t_end
t_summary
