#!/usr/bin/env bash
# tests/unit/session_end.sh: SessionEnd writes docs/progress/<ID>.md on a task
# branch and nothing on a branch without an id.
set -u
. "$(dirname "$0")/../lib/assert.sh"
H="$KIT/plugins/bearing/hooks/scripts/session-end.sh"
repo="$(tmpdir)"; git -C "$repo" init -q -b main
git -C "$repo" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init
git -C "$repo" checkout -q -b feature/TASK-3-list; mkdir -p "$repo/.bearing/state"
t_begin "task branch"
T_IN='{"session_id":"s","reason":"exit"}'
assert_exit 0 bash -c "cd '$repo' && bash '$H'"
assert_eq "" "$T_OUT" "stdout empty"
assert_file "$repo/docs/progress/TASK-3.md"
assert_contains "$(cat "$repo/docs/progress/TASK-3.md")" "feature/TASK-3-list"
assert_eq "" "$(git -C "$repo" log --oneline -1 -- docs/progress)" "nothing committed"
t_end
t_begin "no task id"
git -C "$repo" checkout -q -b feat/Thing
assert_exit 0 bash -c "cd '$repo' && bash '$H'"
assert_eq 1 "$(ls "$repo/docs/progress" | wc -l | tr -d ' ')" "still one file"
assert_contains "$(cat "$repo/.bearing/state/gates.log")" "session-end	not-run	0	no task id on branch"
t_end
t_begin "outside a repository"
notrepo="$(tmpdir)"
assert_exit 0 bash -c "cd '$notrepo' && GIT_CEILING_DIRECTORIES='$notrepo' bash '$H'"
t_end
t_summary
