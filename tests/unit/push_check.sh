#!/usr/bin/env bash
# tests/unit/push_check.sh: brg-push check prints one line per condition and
# the count, refuses outside a repository, and names each unmet condition;
# optin-record writes on or off from the passwd-home bearing.env, matching a
# full push URL entry to origin by url_key, never from the environment.
# bash 3.2 safe.
set -u
. "$(dirname "$0")/../lib/assert.sh"
unset BEARING_ENV BEARING_AUTO_PUSH CLAUDE_PROJECT_DIR
home="$(tmpdir)"; mkdir -p "$home/.config/bearing"; envf="$home/.config/bearing/bearing.env"
# brg-push with the passwd home pointed at the fixture: the one seam.
P="$(tmpdir)/brg-push"
sed '$d' "$KIT/plugins/bearing/bin/brg-push" > "$P"
printf "passwd_home() { printf '%%s\\\\n' '%s'; }\nmain \"\$@\"\n" "$home" >> "$P"

setup() { # a repository on feature/ABC-1-Thing, one commit ahead of origin/main, check passed
  repo="$(tmpdir)"; remote="$(tmpdir)/remote.git"
  git init -q --bare "$remote"
  git -C "$repo" init -q -b main
  git -C "$repo" config user.email t@example.com; git -C "$repo" config user.name t
  printf '.bearing/state/\n' > "$repo/.gitignore"
  printf 'check:\n\t@mkdir -p .bearing/state && touch .bearing/state/.check-passed\n' > "$repo/Makefile"
  git -C "$repo" add .gitignore Makefile; git -C "$repo" commit -q -m "chore: init"
  git -C "$repo" remote add origin "$remote"; git -C "$repo" push -q origin main 2>/dev/null
  git -C "$repo" switch -q -c feature/ABC-1-Thing
  printf 'x\n' > "$repo/a.txt"; git -C "$repo" add a.txt; git -C "$repo" commit -q -m "feat: a [ABC-1]"
  mkdir -p "$repo/.bearing/state"; sleep 1; touch "$repo/.bearing/state/.check-passed"
  printf 'BEARING_AUTO_PUSH="file://%s"\n' "$remote" > "$envf"
  ( cd "$repo" && bash "$P" optin-record )
}
in_repo() { ( cd "$repo" && bash "$P" "$@" ) }
# The functions without main, to call one directly (bash 3.2 cannot source <(...)).
fns="$(tmpdir)/fns.sh"; sed '$d' "$P" > "$fns"
kitfns="$(tmpdir)/kitfns.sh"; sed '$d' "$KIT/plugins/bearing/bin/brg-push" > "$kitfns"
key() { bash -c '. "$1"; url_key "$2"' _ "$fns" "$1"; }

t_begin "outside a git repository: exit 2 and 0 conditions"
d="$(tmpdir)"
assert_exit 2 bash -c "cd '$d' && bash '$P' check"
assert_contains "$T_OUT" "0 conditions checked"
t_end

t_begin "everything met: eight ok lines and the count"
setup
assert_exit 0 in_repo check
assert_contains "$T_OUT" "ok opt-in:"
assert_contains "$T_OUT" "ok origin: localhost/"
assert_contains "$T_OUT" "ok gate: 1 file(s) compared"
assert_contains "$T_OUT" "push-check: 8 conditions, 8 met"
assert_not_contains "$T_OUT" "pre-push"
t_end

t_begin "origin's key not listed in bearing.env"
setup; printf 'BEARING_AUTO_PUSH="git@git.example.test:other/repo.git"\n' > "$envf"; ( cd "$repo" && bash "$P" optin-record )
assert_exit 1 in_repo check
assert_contains "$T_OUT" "no opt-in:"
t_end

t_begin "a host/path entry is not a push URL and does not opt in"
setup; p="${remote%.git}"; printf 'BEARING_AUTO_PUSH="localhost/%s"\n' "${p#/}" > "$envf"; ( cd "$repo" && bash "$P" optin-record )
assert_eq off "$(cat "$repo/.bearing/state/.push-optin")"
t_end

t_begin "an environment variable does not opt in"
setup; : > "$envf"; ( cd "$repo" && BEARING_AUTO_PUSH="file://$remote" bash "$P" optin-record )
assert_exit 1 in_repo check
assert_contains "$T_OUT" "no opt-in:"
t_end

t_begin "a self-supplied BEARING_ENV, XDG_CONFIG_HOME or HOME does not opt in"
setup; : > "$envf"
fake="$(tmpdir)"; mkdir -p "$fake/.config/bearing" "$fake/bearing"
printf 'BEARING_AUTO_PUSH="file://%s"\n' "$remote" | tee "$fake/.config/bearing/bearing.env" "$fake/bearing/bearing.env" > "$fake/env"
for v in "BEARING_ENV=$fake/env" "XDG_CONFIG_HOME=$fake" "HOME=$fake"; do
  ( cd "$repo" && env "$v" bash "$P" optin-record )
  assert_eq off "$(cat "$repo/.bearing/state/.push-optin")" "$v"
done
t_end

t_begin "passwd_home ignores HOME"
real="$(bash -c '. "$1"; passwd_home' _ "$kitfns")"
assert_eq "$real" "$(HOME=/tmp bash -c '. "$1"; passwd_home' _ "$kitfns")"
t_end

t_begin "url_key normalises https, ssh and scp-style URLs the same way"
for u in git@Git.Example.Test:group/shop.git ssh://git@git.example.test:22/group/shop.git https://user:tok@git.example.test/group/shop/; do
  assert_eq "git.example.test/group/shop" "$(key "$u")" "$u"
done
assert_eq "localhost/srv/r" "$(key /srv/r.git)" "local path"
t_end

t_begin "url_key keeps a port other than the default"
assert_eq "git.example.test:2222/group/shop" "$(key ssh://git@git.example.test:2222/group/shop.git)"
assert_eq "git.example.test:8443/group/shop" "$(key https://git.example.test:8443/group/shop)"
t_end

t_begin "url_key refuses http, git, other schemes and helper forms"
for u in http://h/g/r git://h/g/r git+ssh://h/g/r ssh+git://h/g/r ftp://h/g/r 'ext::sh -c x' 'ssh://h:x/g/r' relative/path; do
  assert_exit 1 key "$u"
done
t_end

t_begin "optin-record reads origin's url as a file, not through the repository"
setup; printf 'not a ref\n' > "$repo/.git/HEAD"   # git no longer treats it as a repository
( cd "$repo" && GIT_DIR=/nonexistent bash "$P" optin-record )
assert_eq on "$(cat "$repo/.bearing/state/.push-optin")"
t_end

t_begin "protected and release branches"
setup
git -C "$repo" switch -q main
assert_exit 1 in_repo check; assert_contains "$T_OUT" "no branch:"; assert_contains "$T_OUT" "no not-protected:"
git -C "$repo" switch -q -c release/v1.2.0
assert_exit 1 in_repo check; assert_contains "$T_OUT" "no not-protected:"
t_end

t_begin "detached HEAD"
setup; git -C "$repo" switch -q --detach
assert_exit 1 in_repo check; assert_contains "$T_OUT" "no branch: detached"
t_end

t_begin "dirty tree"
setup; printf 'y\n' >> "$repo/a.txt"
assert_exit 1 in_repo check; assert_contains "$T_OUT" "no clean:"
t_end

t_begin "stale gate"
setup; sleep 1; printf 'z\n' > "$repo/a.txt"; git -C "$repo" commit -q -am "fix: z [ABC-1]"
assert_exit 1 in_repo check; assert_contains "$T_OUT" "no gate: 1 of 1 file(s) newer than the last make check"
t_end

t_begin "an untracked file with a space in its name counts for the gate"
setup; sleep 1; printf 'n\n' > "$repo/new file.txt"
assert_exit 1 in_repo check; assert_contains "$T_OUT" "no gate: 1 of 2 file(s) newer than the last make check"
t_end

t_begin "zero commits ahead"
setup; git -C "$repo" switch -q -c feature/ABC-2-Empty main
assert_exit 1 in_repo check; assert_contains "$T_OUT" "no ahead: 0 commits"
t_end

t_begin "not a fast-forward of origin's branch"
setup
other="$(tmpdir)"; git clone -q "$remote" "$other"; git -C "$other" switch -q -c feature/ABC-1-Thing
git -C "$other" -c user.email=o@example.com -c user.name=o commit -q --allow-empty -m "chore: other"
git -C "$other" push -q origin feature/ABC-1-Thing 2>/dev/null; git -C "$repo" fetch -q origin
assert_exit 1 in_repo check; assert_contains "$T_OUT" "no fast-forward:"
t_end

t_begin "optin-record in a linked worktree reads origin through gitdir and commondir"
setup; wt="$(tmpdir)/wt"; git -C "$repo" worktree add -q -b feature/ABC-3-Wt "$wt" 2>/dev/null
( cd "$wt" && bash "$P" optin-record )
assert_eq on "$(cat "$wt/.bearing/state/.push-optin")"
t_end

t_begin "optin-record never writes through a planted symlink"
setup; victim="$(tmpdir)/victim"; printf 'keep\n' > "$victim"
rm -f "$repo/.bearing/state/.push-optin"; ln -s "$victim" "$repo/.bearing/state/.push-optin"
( cd "$repo" && bash "$P" optin-record )
assert_eq keep "$(cat "$victim")" "the symlink target is untouched"
assert_eq on "$(cat "$repo/.bearing/state/.push-optin")"
elsewhere="$(tmpdir)"; rm -r -f "$repo/.bearing/state"; ln -s "$elsewhere" "$repo/.bearing/state"
( cd "$repo" && bash "$P" optin-record )
assert_eq "" "$(ls -A "$elsewhere")" "nothing written into a symlinked state directory"
t_end

t_summary
