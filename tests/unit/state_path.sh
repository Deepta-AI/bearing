#!/usr/bin/env bash
# tests/unit/state_path.sh: plugins/bearing/bin/brg-state-path, plugins/bearing/hooks/scripts/lib.sh and the
# brg-guard session agree on the state file of a branch with slashes, the
# session finds a file written at that path, and the helper fails outside a
# repository.
set -u
. "$(dirname "$0")/../lib/assert.sh"
SP="$KIT/plugins/bearing/bin/brg-state-path"

repo="$(tmpdir)"; git -C "$repo" init -q -b main
git -C "$repo" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init
git -C "$repo" checkout -q -b feature/TASK-7-Widgets
real="$(cd "$repo" && pwd -P)"

t_begin "the helper maps / to _ under .bearing/state"
assert_exit 0 bash -c "cd '$repo' && '$SP'"
assert_eq "$real/.bearing/state/feature_TASK-7-Widgets.md" "$T_OUT"
assert_exit 0 bash -c "cd '$repo' && '$SP' bugfix/x/y"
assert_eq "$real/.bearing/state/bugfix_x_y.md" "$T_OUT"
t_end

t_begin "lib.sh and the guard session use the same file"
lib="$(cd "$repo" && bash -c ". '$KIT/plugins/bearing/hooks/scripts/lib.sh'; state_file" </dev/null)"
assert_eq "$real/.bearing/state/feature_TASK-7-Widgets.md" "$lib"
mkdir -p "$repo/.bearing/state"; printf 'Next: ship it\n' > "$repo/.bearing/state/feature_TASK-7-Widgets.md"
assert_exit 0 bash -c "cd '$repo' && bash '$GUARD' session"
assert_contains "$T_OUT" "Next: ship it"
t_end

t_begin "outside a repository it fails"
d="$(tmpdir)"
assert_exit 1 bash -c "cd '$d' && GIT_CEILING_DIRECTORIES='$d' '$SP'"
t_end

t_summary
