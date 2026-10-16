#!/usr/bin/env bash
# tests/unit/session_checkpoint.sh: checkpoint content on a task branch and on
# a branch without an id.
set -u
. "$(dirname "$0")/../lib/assert.sh"
S="$KIT/plugins/bearing/bin/brg-session"
repo="$(tmpdir)"; git -C "$repo" init -q -b main
printf '.bearing/state/\n' > "$repo/.gitignore"; git -C "$repo" add -A
git -C "$repo" -c user.email=t@example.com -c user.name=t commit -q -m init
git -C "$repo" checkout -q -b feature/TASK-7-widgets; mkdir -p "$repo/.bearing/state"
printf '# Handoff\nNext: wire the list.\n' > "$repo/.bearing/state/feature_TASK-7-widgets.md"
printf 'x\n' > "$repo/a.txt"
in_repo() { ( cd "$repo" && bash "$S" "$@" ) }
cp="$repo/.bearing/state/feature_TASK-7-widgets.checkpoint.md"

t_begin "task branch"
in_repo timeline-start --id s --skill bearing:start-task; in_repo timeline-close --id s
assert_exit 0 in_repo checkpoint
c="$(cat "$cp")"
assert_contains "$c" "Task: TASK-7"
assert_contains "$c" "Uncommitted: 1 file(s)"
assert_contains "$c" "Recent skills: bearing:start-task"
assert_contains "$c" "Next (from state file): wire the list."
assert_contains "$c" "Next flow step: explain-codebase"
assert_contains "$c" "Ahead/behind: 0/0"
assert_contains "$(cat "$repo/.bearing/state/gates.log")" "checkpoint	written"
t_end

t_begin "branch with no task id"
git -C "$repo" checkout -q -b feat/RuntimeAndFeel
assert_exit 0 in_repo checkpoint
assert_contains "$(cat "$repo/.bearing/state/feat_RuntimeAndFeel.checkpoint.md")" "Task: none"
t_end

t_begin "no origin/HEAD and no main: sensible values, nothing on stderr"
r2="$(tmpdir)"; git -C "$r2" init -q -b trunk
git -C "$r2" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init
mkdir -p "$r2/.bearing"
err="$( cd "$r2" && bash "$S" checkpoint 2>&1 >/dev/null )"
assert_eq "" "$err" "stderr"
c2="$(cat "$r2/.bearing/state/trunk.checkpoint.md")"
assert_contains "$c2" "Base: none none"
assert_contains "$c2" "Ahead/behind: 0/0"
t_end
t_summary
