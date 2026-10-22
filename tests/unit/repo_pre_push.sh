#!/usr/bin/env bash
# tests/unit/repo_pre_push.sh: this repository's own .githooks/pre-push runs
# the gate without the variables git exports to a hook. From a linked worktree
# git sets GIT_DIR and GIT_INDEX_FILE to absolute paths into the main
# repository; a gate that inherits them sends every test's `git init`, commit
# and tag in a temp folder into the real repository instead (19 Oct 2026: fake
# tags, branches and config in the Bearing clone). tests/lib/assert.sh drops
# them too. A fake make stands in for the gate. bash 3.2 safe.
set -u
. "$(dirname "$0")/../lib/assert.sh"

d="$(tmpdir)"
repo="$d/repo"; remote="$d/r.git"; wt="$d/wt"; bin="$d/bin"; probe="$d/probe"
git init -q --bare "$remote"
git init -q -b main "$repo"
mkdir -p "$repo/.githooks" "$bin"
cp "$KIT/.githooks/pre-push" "$repo/.githooks/pre-push"
git -C "$repo" config user.email t@example.com; git -C "$repo" config user.name t
git -C "$repo" config commit.gpgsign false
git -C "$repo" add -A; git -C "$repo" commit -q -m "chore: init"
git -C "$repo" config core.hooksPath .githooks
git -C "$repo" remote add origin "$remote"
git -C "$repo" worktree add -q -b feat/T-1-Wt "$wt"
git -C "$wt" commit -q --allow-empty -m "feat: in a worktree"

# The fake gate does what the real tests do: git in a fresh temp folder.
cat > "$bin/make" <<S
#!/usr/bin/env bash
env | grep -E '^GIT_(DIR|INDEX_FILE|WORK_TREE|COMMON_DIR|OBJECT_DIRECTORY)=' > "$probe"
t="\$(mktemp -d "$d/gate.XXXXXX")"
git init -q "\$t"
git -C "\$t" -c user.email=g@example.com -c user.name=g commit -q --allow-empty -m "gate fixture"
git -C "\$t" tag leaked-tag
git -C "\$t" config gate.leak yes
exit 0
S
chmod 755 "$bin/make"

t_begin "a push from a linked worktree runs the gate without git's hook variables"
assert_exit 0 env -u CLAUDECODE PATH="$bin:$PATH" git -C "$wt" push -q origin feat/T-1-Wt
assert_eq "" "$(cat "$probe")" "GIT_* variables the gate saw"
assert_eq "" "$(git -C "$repo" tag -l leaked-tag)" "tag in the real repository"
assert_eq "" "$(git -C "$repo" config --get gate.leak)" "config in the real repository"
assert_eq "feat: in a worktree" "$(git -C "$repo" log -1 --format=%s feat/T-1-Wt)" "branch tip"
assert_eq "feat/T-1-Wt" "$(git --git-dir="$remote" for-each-ref --format='%(refname:short)' refs/heads/feat)" "pushed"
t_end

t_begin "the test library drops git's repository variables"
assert_exit 0 env GIT_DIR="$repo/.git" GIT_INDEX_FILE="$repo/.git/index" GIT_WORK_TREE="$repo" \
  bash -c ". '$KIT/tests/lib/assert.sh'; echo \"dir=\${GIT_DIR-unset} index=\${GIT_INDEX_FILE-unset} tree=\${GIT_WORK_TREE-unset}\""
assert_contains "$T_OUT" "dir=unset index=unset tree=unset"
t_end

t_summary
