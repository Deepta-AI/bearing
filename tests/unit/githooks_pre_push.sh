#!/usr/bin/env bash
# tests/unit/githooks_pre_push.sh: the committed pre-push hook refuses an agent
# push without the opt-in, allows a fast-forward task branch with it, and
# refuses a tag, a protected or release branch, a deletion and a forced update
# with it. The opt-in is a <host>/<path> entry in bearing.env under the passwd
# home, bound to the URL git pushes to: another URL, another host, another
# remote, a differing pushurl or a self-supplied BEARING_ENV, XDG_CONFIG_HOME
# or HOME does not count, and neither does an exported BEARING_AUTO_PUSH.
# bash 3.2 safe.
set -u
. "$(dirname "$0")/../lib/assert.sh"
H="$KIT/plugins/bearing/templates/repo/.githooks"
unset BEARING_ENV BEARING_AUTO_PUSH
home="$(tmpdir)"; mkdir -p "$home/.config/bearing"; envf="$home/.config/bearing/bearing.env"
srv="$(tmpdir)"
# A stand-in for ssh: runs the git command it is handed against $srv, whatever
# the host, so the hook sees a real ssh or scp-style URL in $2.
fakessh="$srv/fake-ssh"
printf '#!/bin/sh\nfor a; do last="$a"; done\ncmd="${last%%%% *}"; p="${last#* }"; p="$(eval "printf %%s $p")"\nexec $cmd "%s/${p#/}"\n' "$srv" > "$fakessh"
chmod +x "$fakessh"
export GIT_SSH_COMMAND="$fakessh" GIT_SSH_VARIANT=simple
git init -q --bare "$srv/group/shop.git"

setup() {
  repo="$(tmpdir)"; remote="$(tmpdir)/r.git"; git init -q --bare "$remote"
  git -C "$repo" init -q -b main; cp -R "$H" "$repo/.githooks"
  # The fixture's passwd home: the one seam, written into the fixture's own
  # copy of lib.sh (an agent that can edit the committed hooks needs no seam).
  printf "passwd_home() { printf '%%s\\\\n' '%s'; }\n" "$home" >> "$repo/.githooks/lib.sh"
  git -C "$repo" config user.email t@example.com; git -C "$repo" config user.name t
  git -C "$repo" config commit.gpgsign false
  printf 'check:\n\t@echo check: passed\n' > "$repo/Makefile"; git -C "$repo" add -A; git -C "$repo" commit -q -m "chore: init"
  git -C "$repo" remote add origin "$remote"; git -C "$repo" push -q origin main 2>/dev/null
  git -C "$repo" config core.hooksPath .githooks
  git -C "$repo" switch -q -c feature/ABC-1-Thing; git -C "$repo" commit -q --allow-empty -m "feat: a [ABC-1]"
  p="${remote%.git}"; key="localhost/${p#/}"
  printf 'BEARING_AUTO_PUSH="%s"\n' "$key" > "$envf"
}
# XDG_CONFIG_HOME points at the same file, so a hook that still honoured it
# would see the same opt-in; the self-supplied cases below point it elsewhere.
agent_push() { ( cd "$repo" && CLAUDECODE=1 XDG_CONFIG_HOME="$home/.config" git push "$@" 2>&1 ) }
fake() { d="$(tmpdir)"; mkdir -p "$d/bearing"; printf 'BEARING_AUTO_PUSH="%s"\n' "$1" > "$d/bearing/bearing.env"; printf '%s' "$d"; }

t_begin "agent push refused without the opt-in"
setup; : > "$envf"
t_run agent_push origin HEAD:refs/heads/feature/ABC-1-Thing
assert_contains "$T_OUT" "a coding agent is pushing"
t_end

t_begin "an exported BEARING_AUTO_PUSH does not opt in"
setup; : > "$envf"
t_run env BEARING_AUTO_PUSH="$key" bash -c "$(declare -f agent_push); repo='$repo'; home='$home'; agent_push origin HEAD:refs/heads/feature/ABC-1-Thing"
assert_contains "$T_OUT" "a coding agent is pushing"
t_end

t_begin "agent push of a feature branch allowed with the opt-in, gate run"
setup
t_run agent_push --no-follow-tags origin HEAD:refs/heads/feature/ABC-1-Thing
assert_contains "$T_OUT" "agent push allowed by BEARING_AUTO_PUSH: 1 branch ref(s)"
assert_contains "$T_OUT" "gate passed"
t_end

t_begin "a repository not listed in the opt-in is refused"
setup; printf 'BEARING_AUTO_PUSH="localhost/other/repo"\n' > "$envf"
t_run agent_push origin HEAD:refs/heads/feature/ABC-1-Thing
assert_contains "$T_OUT" "a coding agent is pushing"
assert_contains "$T_OUT" "is not listed in BEARING_AUTO_PUSH"
t_end

t_begin "a path-only entry without the host does not match"
setup; printf 'BEARING_AUTO_PUSH="%s"\n' "${p#/}" > "$envf"
t_run agent_push origin HEAD:refs/heads/feature/ABC-1-Thing
assert_contains "$T_OUT" "a coding agent is pushing"
t_end

t_begin "a push straight to an unlisted URL is refused"
setup; other="$(tmpdir)/x.git"; git init -q --bare "$other"
t_run agent_push "$other" HEAD:refs/heads/feature/ABC-1-Exfil
assert_contains "$T_OUT" "a coding agent is pushing"
assert_not_contains "$T_OUT" "gate passed"
t_end

t_begin "origin re-pointed at an unlisted URL is refused"
setup; other="$(tmpdir)/x.git"; git init -q --bare "$other"; git -C "$repo" remote set-url origin "$other"
t_run agent_push origin HEAD:refs/heads/feature/ABC-1-Thing
assert_contains "$T_OUT" "is not listed in BEARING_AUTO_PUSH"
t_end

t_begin "a pushurl that differs from the url is refused"
setup; other="$(tmpdir)/x.git"; git init -q --bare "$other"; git -C "$repo" config remote.origin.pushurl "$other"
t_run agent_push origin HEAD:refs/heads/feature/ABC-1-Exfil
assert_contains "$T_OUT" "a coding agent is pushing"
assert_contains "$T_OUT" "pushurl"
t_end

t_begin "a pushInsteadOf redirect is judged on the rewritten URL"
setup; other="$(tmpdir)/x.git"; git init -q --bare "$other"; git -C "$repo" config "url.$other.pushInsteadOf" "$remote"
t_run agent_push origin HEAD:refs/heads/feature/ABC-1-Exfil
assert_contains "$T_OUT" "is not listed in BEARING_AUTO_PUSH"
t_end

t_begin "another remote name is refused even when its URL is listed"
setup; git -C "$repo" remote add mirror "$remote"
t_run agent_push mirror HEAD:refs/heads/feature/ABC-1-Thing
assert_contains "$T_OUT" "a coding agent is pushing"
assert_contains "$T_OUT" "not origin"
t_end

t_begin "a listed path on another host is refused (ssh and scp forms)"
setup; printf 'BEARING_AUTO_PUSH="git.example.test/group/shop"\n' > "$envf"
git -C "$repo" remote set-url origin "ssh://git@evil.example.test/group/shop.git"
t_run agent_push origin HEAD:refs/heads/feature/ABC-1-Thing
assert_contains "$T_OUT" "evil.example.test/group/shop is not listed in BEARING_AUTO_PUSH"
git -C "$repo" remote set-url origin "git@evil.example.test:group/shop.git"
t_run agent_push origin HEAD:refs/heads/feature/ABC-1-Thing
assert_contains "$T_OUT" "evil.example.test/group/shop is not listed in BEARING_AUTO_PUSH"
t_end

t_begin "a listed host/path is allowed in ssh and scp-style form"
setup; printf 'BEARING_AUTO_PUSH="git.example.test/group/shop"\n' > "$envf"
git -C "$repo" remote set-url origin "ssh://git@git.example.test/group/shop.git"
t_run agent_push origin HEAD:refs/heads/feature/ABC-1-Thing
assert_contains "$T_OUT" "agent push allowed by BEARING_AUTO_PUSH: 1 branch ref(s)"
assert_contains "$T_OUT" "gate passed"
git -C "$repo" remote set-url origin "git@git.example.test:group/shop.git"
git -C "$repo" commit -q --allow-empty -m "feat: b [ABC-1]"
t_run agent_push origin HEAD:refs/heads/feature/ABC-1-Thing
assert_contains "$T_OUT" "agent push allowed by BEARING_AUTO_PUSH: 1 branch ref(s)"
t_end

t_begin "url_key normalises https, ssh and scp-style URLs the same way"
for u in https://git.example.test/group/shop.git https://user:tok@Git.Example.Test:8443/group/shop/ \
         ssh://git@git.example.test:2222/group/shop.git git@git.example.test:group/shop.git git.example.test:/group/shop; do
  assert_eq "git.example.test/group/shop" "$(bash -c '. "$1/lib.sh"; url_key "$2"' _ "$H" "$u")" "$u"
done
assert_eq "localhost/srv/git/shop" "$(bash -c '. "$1/lib.sh"; url_key "$2"' _ "$H" /srv/git/shop.git)" "local path"
assert_exit 1 bash -c '. "$1/lib.sh"; url_key "$2"' _ "$H" ../relative/shop.git
t_end

t_begin "passwd_home ignores HOME"
t_run bash -c '. "$1/lib.sh"; HOME=/nonexistent/fake passwd_home' _ "$H"
assert_not_contains "$T_OUT" "/nonexistent/fake"
t_end

t_begin "a self-supplied BEARING_ENV, XDG_CONFIG_HOME or HOME does not opt in"
setup; : > "$envf"; f="$(fake "$key")"
t_run bash -c "cd '$repo' && CLAUDECODE=1 BEARING_ENV='$f/bearing/bearing.env' git push origin HEAD:refs/heads/feature/ABC-1-Thing 2>&1"
assert_contains "$T_OUT" "a coding agent is pushing" "BEARING_ENV"
t_run bash -c "cd '$repo' && CLAUDECODE=1 XDG_CONFIG_HOME='$f' git push origin HEAD:refs/heads/feature/ABC-1-Thing 2>&1"
assert_contains "$T_OUT" "a coding agent is pushing" "XDG_CONFIG_HOME"
mkdir -p "$f/.config"; cp -R "$f/bearing" "$f/.config/bearing"
t_run bash -c "cd '$repo' && CLAUDECODE=1 HOME='$f' git push origin HEAD:refs/heads/feature/ABC-1-Thing 2>&1"
assert_contains "$T_OUT" "a coding agent is pushing" "HOME"
t_end

t_begin "a tag-only agent push without the opt-in is refused"
setup; : > "$envf"; git -C "$repo" tag v1.0.0
t_run agent_push origin v1.0.0
assert_contains "$T_OUT" "an agent push carries only branches"
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
