#!/usr/bin/env bash
# tests/unit/dod_red_proof.sh: plugins/bearing/skills/definition-of-done/scripts/red_proof.sh proves a
# regression test is green with the fix and red without it, in a throwaway
# worktree, leaving the working tree untouched; and fails when the test
# passes without the fix, fails with it, or when the diff holds no test or
# no non-test file.
set -u
. "$(dirname "$0")/../lib/assert.sh"
RP="$KIT/plugins/bearing/skills/definition-of-done/scripts/red_proof.sh"
g() { git -C "$repo" -c user.email=t@example.com -c user.name=t "$@"; }

# repo with a buggy add() on main
setup() {
  repo="$(tmpdir)"; git -C "$repo" init -q -b main
  printf '.scratch/\n' > "$repo/.gitignore"
  printf 'def add(a, b):\n    return a - b\n' > "$repo/calc.py"
  g add -A; g commit -q -m "feat: add"
  g checkout -q -b bugfix/TASK-9-Add
}
TEST_CMD='python3 test_calc.py'
test_file() { printf 'from calc import add\nassert add(2, 3) == 5, "add is wrong"\nprint("ok")\n' > "$repo/test_calc.py"; }

t_begin "green with the fix, red without it"
setup
printf 'def add(a, b):\n    return a + b\n' > "$repo/calc.py"; printf 'VERSION = 2\n' > "$repo/extra.py"; test_file
g add -A; g commit -q -m "fix: add adds [TASK-9]"
assert_exit 0 bash -c "cd '$repo' && bash '$RP' main '$TEST_CMD'"
assert_contains "$T_OUT" "with the fix (HEAD): exit 0"
assert_contains "$T_OUT" "without the fix (1 files back to main, 1 added files removed): exit 1"
assert_contains "$T_OUT" "add is wrong"
assert_contains "$T_OUT" "1 test files, 2 non-test files; green with the fix, red without it: proven"
assert_eq "" "$(git -C "$repo" status --porcelain)" "working tree untouched"
assert_eq "" "$(git -C "$repo" worktree list | grep dod-red)" "worktree removed"
t_end

t_begin "a test that passes without the fix proves nothing"
setup
printf 'def add(a, b):\n    return a + b\n' > "$repo/calc.py"
printf 'print("ok")\n' > "$repo/test_calc.py"
g add -A; g commit -q -m "fix: add [TASK-9]"
assert_exit 1 bash -c "cd '$repo' && bash '$RP' main '$TEST_CMD'"
assert_contains "$T_OUT" "GREEN without the fix: the test does not prove the bug"
t_end

t_begin "a test that fails with the fix is not a proof"
setup
test_file; g add -A; g commit -q -m "test: add [TASK-9]"
printf '# note\n' >> "$repo/calc.py"; g add -A; g commit -q -m "chore: note"
assert_exit 1 bash -c "cd '$repo' && bash '$RP' main '$TEST_CMD'"
assert_contains "$T_OUT" "fails with the fix in a clean worktree"
t_end

t_begin "no test file, no non-test file and bad usage fail"
setup
printf 'def add(a, b):\n    return a + b\n' > "$repo/calc.py"; g add -A; g commit -q -m "fix: add"
assert_exit 1 bash -c "cd '$repo' && bash '$RP' main '$TEST_CMD'"
assert_contains "$T_OUT" "0 test files changed"
setup
test_file; g add -A; g commit -q -m "test: only"
assert_exit 1 bash -c "cd '$repo' && bash '$RP' main '$TEST_CMD'"
assert_contains "$T_OUT" "0 non-test files changed"
assert_exit 2 bash -c "cd '$repo' && bash '$RP' main"
assert_exit 2 bash -c "cd '$repo' && bash '$RP' no-such-base '$TEST_CMD'"
t_end

t_summary
