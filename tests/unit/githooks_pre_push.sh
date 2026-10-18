#!/usr/bin/env bash
# tests/unit/githooks_pre_push.sh: the committed pre-push hook refuses every
# coding agent's push, a BEARING_AUTO_PUSH entry or not, and refuses an
# agent's tag push even when no branch is pushed; the engineer's push runs
# the gate; the hooks carry no opt-in code (Bearing's opt-in push runs from
# a fresh clone and never meets this hook). bash 3.2 safe.
set -u
. "$(dirname "$0")/../lib/assert.sh"
H="$KIT/plugins/bearing/templates/repo/.githooks"
H2="$KIT/plugins/bearing/skills/git-hooks/templates/.githooks"
unset BEARING_ENV BEARING_AUTO_PUSH
home="$(tmpdir)"; mkdir -p "$home/.config/bearing"; envf="$home/.config/bearing/bearing.env"
setup() {
  repo="$(tmpdir)"; remote="$(tmpdir)/r.git"; git init -q --bare "$remote"
  git -C "$repo" init -q -b main; cp -R "$H" "$repo/.githooks"
  # A passwd home for the fixture: the hooks before this task read the
  # opt-in there; after it nothing reads it, and the entry must not matter.
  printf "passwd_home() { printf '%%s\\\\n' '%s'; }\n" "$home" >> "$repo/.githooks/lib.sh"
  git -C "$repo" config user.email t@example.com; git -C "$repo" config user.name t
  git -C "$repo" config commit.gpgsign false
  printf 'check:\n\t@echo check: passed\n' > "$repo/Makefile"; git -C "$repo" add -A; git -C "$repo" commit -q -m "chore: init"
  git -C "$repo" remote add origin "$remote"; git -C "$repo" push -q origin main 2>/dev/null
  git -C "$repo" config core.hooksPath .githooks
  git -C "$repo" switch -q -c feature/ABC-1-Thing; git -C "$repo" commit -q --allow-empty -m "feat: a [ABC-1]"
  : > "$envf"
}
agent_push() { ( cd "$repo" && CLAUDECODE=1 git push "$@" 2>&1 ) }
landed() { git --git-dir="$remote" for-each-ref --format='%(refname)' 'refs/heads/feature/*' 'refs/tags/*'; }

t_begin "an agent push of a task branch is refused"
setup
t_run agent_push origin HEAD:refs/heads/feature/ABC-1-Thing
assert_contains "$T_OUT" "a coding agent is pushing (CLAUDECODE is set); the engineer runs git push"
assert_eq "" "$(landed)" "nothing landed"
t_end

t_begin "a BEARING_AUTO_PUSH entry does not let an agent push through the hook"
setup
p="${remote%.git}"
printf 'BEARING_AUTO_PUSH="localhost/%s file://%s"\n' "${p#/}" "$remote" > "$envf"
t_run agent_push --no-follow-tags origin HEAD:refs/heads/feature/ABC-1-Thing
assert_contains "$T_OUT" "a coding agent is pushing (CLAUDECODE is set); the engineer runs git push"
assert_not_contains "$T_OUT" "auto push"
assert_eq "" "$(landed)" "nothing landed"
t_end

t_begin "an agent tag-only push is refused"
setup; git -C "$repo" tag v1.0.0
t_run agent_push origin v1.0.0
assert_contains "$T_OUT" "an agent push carries only branches: refs/tags/v1.0.0"
assert_eq "" "$(landed)" "nothing landed"
t_end

t_begin "an agent push of a branch and a tag is refused at the tag"
setup; git -C "$repo" tag -a v1.0.1 -m "v1.0.1"   # annotated: --follow-tags sends only those
t_run agent_push --follow-tags origin HEAD:refs/heads/feature/ABC-1-Thing
assert_contains "$T_OUT" "an agent push carries only branches: refs/tags/v1.0.1"
assert_eq "" "$(landed)" "nothing landed"
t_end

t_begin "an agent push to main is refused"
setup
t_run agent_push origin HEAD:refs/heads/main
assert_contains "$T_OUT" "direct push to main is not allowed"
t_end

t_begin "with PUSH_CONFIRM=off an agent push goes through as before"
setup; printf "PUSH_CONFIRM='off'\n" >> "$repo/.githooks/lib.sh"
t_run agent_push origin HEAD:refs/heads/feature/ABC-1-Thing
assert_contains "$T_OUT" "gate passed"
assert_eq "refs/heads/feature/ABC-1-Thing" "$(landed)"
t_end

t_begin "the engineer's push of a task branch runs the gate"
setup; printf "PUSH_CONFIRM='agents'\n" >> "$repo/.githooks/lib.sh"
t_run bash -c "cd '$repo' && env -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT git push origin HEAD:refs/heads/feature/ABC-1-Thing 2>&1"
assert_contains "$T_OUT" "1 branch ref(s), 1 commit message(s) checked, gate passed"
t_end

t_begin "the hooks carry no opt-in code"
n=0
for f in "$H/lib.sh" "$H/pre-push" "$H2/lib.sh" "$H2/pre-push"; do
  n=$((n+1))
  assert_eq "" "$(grep -nE 'auto_push_allowed|url_key|passwd_home|transport_redirect|BRG_PUSH_PARAMS|AUTO_WHY|BEARING_AUTO_PUSH' "$f")" "$f"
done
assert_eq 4 "$n" "four hook files checked"
t_end

t_begin "the two copies of the hooks are identical"
assert_exit 0 diff -rq "$H" "$H2"
t_end

t_summary
