#!/usr/bin/env bash
# tests/unit/repo_pre_push.sh: this repository's own .githooks/pre-push checks
# that `make gate` passed on every commit being pushed (bin/gate-mark) and
# never runs the gate itself: git opens the connection to the remote before
# the hook, and a 15-minute gate outlived it, so pushes failed though the gate
# passed. An ungated push is refused at once with nothing sent. A pass is kept
# per commit in the common git directory, so it counts for every branch and
# worktree. tests/lib/assert.sh drops git's repository variables (a hook from
# a linked worktree exports them). A fake make records if anything runs it.
# bash 3.2 safe.
set -u
. "$(dirname "$0")/../lib/assert.sh"

d="$(tmpdir)"
repo="$d/repo"; remote="$d/r.git"; wt="$d/wt"; bin="$d/bin"; ran="$d/make-ran"
git init -q --bare "$remote"
git init -q -b main "$repo"
mkdir -p "$repo/.githooks" "$repo/bin" "$bin"
cp "$KIT/.githooks/pre-push" "$repo/.githooks/pre-push"
cp "$KIT/bin/gate-mark" "$repo/bin/gate-mark"
g() { git -C "$1" -c user.email=t@example.com -c user.name=t -c commit.gpgsign=false "${@:2}"; }
g "$repo" add -A; g "$repo" commit -q -m "chore: init"
git -C "$repo" config core.hooksPath .githooks
git -C "$repo" remote add origin "$remote"
printf '#!/bin/sh\ntouch %s\nexit 0\n' "$ran" > "$bin/make"; chmod 755 "$bin/make"
push() { T_IN=""; t_run env -u CLAUDECODE PATH="$bin:$PATH" git -C "${DIR:-$repo}" push "$@"; }
on_remote() { git --git-dir="$remote" for-each-ref --format='%(refname:short)' "$@"; }
mark() { ( cd "${DIR:-$repo}" && bash bin/gate-mark add "$1" ); }

t_begin "a commit the gate has not passed on is refused at once, nothing sent, no gate run"
push origin main
assert_eq 1 "$T_RC" "exit"
assert_contains "$T_OUT" "the gate has not passed on: $(git -C "$repo" rev-parse --short=7 HEAD) (heads/main)"
assert_contains "$T_OUT" "run make push"
assert_eq "" "$(on_remote refs/heads)" "nothing on the remote"
assert_eq "no" "$([ -e "$ran" ] && echo yes || echo no)" "make ran"
t_end

t_begin "a commit the gate passed on goes straight through"
mark HEAD
push -q origin main
assert_eq 0 "$T_RC" "exit"
assert_contains "$T_OUT" "the gate passed on the 1 commit(s) being pushed"
assert_eq "main" "$(on_remote refs/heads)" "on the remote"
t_end

t_begin "passes are kept per commit: gating a second branch does not undo the first"
git -C "$repo" switch -q -c feat/a; g "$repo" commit -q --allow-empty -m "feat: a"; mark HEAD
git -C "$repo" switch -q -c feat/b main; g "$repo" commit -q --allow-empty -m "feat: b"; mark HEAD
push -q origin feat/a feat/b
assert_eq 0 "$T_RC" "exit"
assert_contains "$T_OUT" "the gate passed on the 2 commit(s) being pushed"
t_end

t_begin "a tag counts the commit it points at; deleting a remote branch needs no gate"
g "$repo" tag -a v1 -m v1 feat/a
push -q origin v1
assert_eq 0 "$T_RC" "tagged commit passed"
g "$repo" commit -q --allow-empty -m "feat: ungated"; g "$repo" tag -a v2 -m v2
push -q origin v2
assert_eq 1 "$T_RC" "tag on an ungated commit"
push -q origin --delete feat/b
assert_eq 0 "$T_RC" "deletion"
t_end

t_begin "a pass recorded in the main checkout counts in a linked worktree"
git -C "$repo" worktree add -q -b feat/wt "$wt" main
g "$wt" commit -q --allow-empty -m "feat: in a worktree"
DIR="$wt" push -q origin feat/wt
assert_eq 1 "$T_RC" "ungated, from the worktree"
mark "$(git -C "$wt" rev-parse HEAD)"
DIR="$wt" push -q origin feat/wt
assert_eq 0 "$T_RC" "gated in the main checkout, pushed from the worktree"
assert_eq "no" "$([ -e "$ran" ] && echo yes || echo no)" "make never ran"
t_end

t_begin "make gate records through gate-mark, and make push gates then pushes"
mk="$(cat "$KIT/Makefile")"
assert_contains "$mk" 'bash bin/gate-mark add "$$head"'
assert_contains "$mk" 'if bash bin/gate-mark has HEAD; then'
assert_not_contains "$mk" 'bearing-gate-passed'
t_end

t_begin "the test library drops git's repository variables"
assert_exit 0 env GIT_DIR="$repo/.git" GIT_INDEX_FILE="$repo/.git/index" GIT_WORK_TREE="$repo" \
  bash -c ". '$KIT/tests/lib/assert.sh'; echo \"dir=\${GIT_DIR-unset} index=\${GIT_INDEX_FILE-unset} tree=\${GIT_WORK_TREE-unset}\""
assert_contains "$T_OUT" "dir=unset index=unset tree=unset"
t_end

t_summary
