#!/usr/bin/env bash
# tests/unit/githooks_pre_push.sh: the committed pre-push hook refuses an agent
# push without the opt-in, allows a fast-forward feature branch with it, and
# refuses a tag, a protected or release branch, a deletion and a forced update
# with it. The opt-in is read from bearing.env only: an exported
# BEARING_AUTO_PUSH does not count. bash 3.2 safe.
set -u
. "$(dirname "$0")/../lib/assert.sh"
H="$KIT/plugins/bearing/templates/repo/.githooks"
cfg="$(tmpdir)"; mkdir -p "$cfg/bearing"; envf="$cfg/bearing/bearing.env"; unset BEARING_ENV BEARING_AUTO_PUSH
setup() {
  repo="$(tmpdir)"; remote="$(tmpdir)/r.git"; git init -q --bare "$remote"
  git -C "$repo" init -q -b main; cp -R "$H" "$repo/.githooks"
  git -C "$repo" config user.email t@example.com; git -C "$repo" config user.name t
  git -C "$repo" config commit.gpgsign false
  printf 'check:\n\t@echo check: passed\n' > "$repo/Makefile"; git -C "$repo" add -A; git -C "$repo" commit -q -m "chore: init"
  git -C "$repo" remote add origin "$remote"; git -C "$repo" push -q origin main 2>/dev/null
  git -C "$repo" config core.hooksPath .githooks
  git -C "$repo" switch -q -c feature/ABC-1-Thing; git -C "$repo" commit -q --allow-empty -m "feat: a [ABC-1]"
  p="${remote%.git}"; printf 'BEARING_AUTO_PUSH="%s"\n' "${p#/}" > "$envf"
}
agent_push() { ( cd "$repo" && CLAUDECODE=1 XDG_CONFIG_HOME="$cfg" git push "$@" 2>&1 ) }

t_begin "agent push refused without the opt-in"
setup; : > "$envf"
t_run agent_push origin HEAD:refs/heads/feature/ABC-1-Thing
assert_contains "$T_OUT" "a coding agent is pushing"
t_end

t_begin "an exported BEARING_AUTO_PUSH does not opt in"
setup; : > "$envf"
t_run env BEARING_AUTO_PUSH="${p#/}" bash -c "$(declare -f agent_push); repo='$repo'; cfg='$cfg'; agent_push origin HEAD:refs/heads/feature/ABC-1-Thing"
assert_contains "$T_OUT" "a coding agent is pushing"
t_end

t_begin "agent push of a feature branch allowed with the opt-in, gate run"
setup
t_run agent_push --no-follow-tags origin HEAD:refs/heads/feature/ABC-1-Thing
assert_contains "$T_OUT" "agent push allowed by BEARING_AUTO_PUSH: 1 branch ref(s)"
assert_contains "$T_OUT" "gate passed"
t_end

t_begin "a repository not listed in the opt-in is refused"
setup; printf 'BEARING_AUTO_PUSH="other/repo"\n' > "$envf"
t_run agent_push origin HEAD:refs/heads/feature/ABC-1-Thing
assert_contains "$T_OUT" "a coding agent is pushing"
t_end

t_begin "a tag is refused even with the opt-in"
setup; git -C "$repo" tag v1.0.0
t_run agent_push origin v1.0.0
assert_contains "$T_OUT" "an agent push carries only branches"
t_end

t_begin "a protected branch is refused with the opt-in"
setup
t_run agent_push origin HEAD:refs/heads/main
assert_contains "$T_OUT" "direct push to main is not allowed"
t_end

t_begin "a release branch is refused with the opt-in"
setup
t_run agent_push origin HEAD:refs/heads/release/v1.0.0
assert_contains "$T_OUT" "direct push to release/v1.0.0 is not allowed"
t_end

t_begin "a branch deletion is refused with the opt-in"
setup; agent_push origin HEAD:refs/heads/feature/ABC-1-Thing >/dev/null
t_run agent_push origin :refs/heads/feature/ABC-1-Thing
assert_contains "$T_OUT" "never deletes a branch"
t_end

t_begin "a forced update is refused with the opt-in"
setup; agent_push origin HEAD:refs/heads/feature/ABC-1-Thing >/dev/null
git -C "$repo" commit -q --allow-empty --amend -m "feat: b [ABC-1]"
t_run agent_push --force origin HEAD:refs/heads/feature/ABC-1-Thing
assert_contains "$T_OUT" "an agent push is never forced"
t_end

t_begin "the two copies of the hooks are identical"
assert_exit 0 diff -rq "$H" "$KIT/plugins/bearing/skills/git-hooks/templates/.githooks"
t_end

t_summary
