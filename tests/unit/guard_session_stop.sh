#!/usr/bin/env bash
# tests/unit/guard_session_stop.sh: brg-guard session, stop and task-id in an
# empty repository, on a task branch with a handoff state file, and with a
# fresh or a stale .check-passed marker.
set -u
. "$(dirname "$0")/../lib/assert.sh"

repo="$(tmpdir)"
git -C "$repo" init -q -b main
printf '.bearing/state/\n' > "$repo/.gitignore"
git -C "$repo" add .gitignore
git -C "$repo" -c user.email=t@example.com -c user.name=t commit -q -m "init"
in_repo() { ( cd "$repo" && bash "$GUARD" "$@" ) }

t_begin "session in an empty repository"
assert_exit 0 in_repo session
assert_contains "$T_OUT" "bearing session: branch=main task=none changed_files=0"
assert_not_contains "$T_OUT" "Handoff state"
t_end

t_begin "session outside a repository"
notrepo="$(tmpdir)"
assert_exit 0 bash -c "cd '$notrepo' && GIT_CEILING_DIRECTORIES='$notrepo' bash '$GUARD' session"
assert_contains "$T_OUT" "not a git repository"
t_end

t_begin "session on a task branch with a state file and a CLAUDE.md note"
git -C "$repo" checkout -q -b feature/TASK-142-widgets
mkdir -p "$repo/.bearing/state"
printf '# Handoff\n\nNext: wire the widget list.\n' > "$repo/.bearing/state/feature_TASK-142-widgets.md"
printf '# Not an import\n' > "$repo/CLAUDE.md"
assert_exit 0 in_repo session
assert_contains "$T_OUT" "branch=feature/TASK-142-widgets task=TASK-142"
assert_contains "$T_OUT" "Handoff state from the previous session (.bearing/state/feature_TASK-142-widgets.md)"
assert_contains "$T_OUT" "Next: wire the widget list."
assert_contains "$T_OUT" "CLAUDE.md does not start with @AGENTS.md"
printf '@AGENTS.md\n' > "$repo/CLAUDE.md"
assert_exit 0 in_repo session
assert_not_contains "$T_OUT" "does not start with"
t_end

t_begin "task-id prints the id from the branch when the prompt lacks it"
assert_exit 0 in_repo task-id "fix the widget list"
assert_contains "$T_OUT" "Task: TASK-142 (from branch feature/TASK-142-widgets). Use it in commit messages as [TASK-142]."
assert_exit 0 in_repo task-id "continue TASK-142 please"
assert_eq "" "$T_OUT" "prompt already carries the id"
assert_exit 0 in_repo task-id "__BRG_UNPARSED__"
assert_eq "" "$T_OUT" "sentinel is a no-op"
assert_exit 0 in_repo task-id ""
assert_contains "$T_OUT" "Task: TASK-142"
t_end

t_begin "stop is silent with no changes"
git -C "$repo" add -A
git -C "$repo" -c user.email=t@example.com -c user.name=t commit -q -m "state"
assert_exit 0 in_repo stop
assert_eq "" "$T_OUT"
t_end

t_begin "stop reminds when files changed and no marker exists"
printf 'x\n' > "$repo/new.txt"
assert_exit 0 in_repo stop
assert_contains "$T_OUT" "bearing: 1 changed file(s) and make check has not passed since"
t_end

t_begin "stop is silent with a fresh marker"
touch "$repo/.bearing/state/.check-passed"
assert_exit 0 in_repo stop
assert_eq "" "$T_OUT"
t_end

t_begin "stop reminds again with a stale marker"
touch -t 202001010000 "$repo/.bearing/state/.check-passed"
printf 'y\n' > "$repo/new.txt"
printf 'z\n' > "$repo/other.txt"
assert_exit 0 in_repo stop
assert_contains "$T_OUT" "2 changed file(s) and make check has not passed since"
t_end

t_begin "stop outside a repository exits 0 silently"
assert_exit 0 bash -c "cd '$notrepo' && GIT_CEILING_DIRECTORIES='$notrepo' bash '$GUARD' stop"
assert_eq "" "$T_OUT"
t_end

t_begin "help and unknown subcommand exit 2"
assert_exit 2 bash "$GUARD"
assert_contains "$T_OUT" "brg-guard command"
assert_exit 2 bash "$GUARD" bogus
assert_contains "$T_OUT" "unknown subcommand bogus"
t_end

t_summary
