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

t_begin "optin-record never moves its file into a directory a .push-optin link points at"
setup; victim="$(tmpdir)"
rm -f "$repo/.bearing/state/.push-optin"; ln -s "$victim" "$repo/.bearing/state/.push-optin"
( cd "$repo" && bash "$P" optin-record )
assert_eq "" "$(ls -A "$victim")" "the linked directory is untouched"
assert_eq on "$(cat "$repo/.bearing/state/.push-optin")"
if [ -L "$repo/.bearing/state/.push-optin" ]; then assert_eq file link ".push-optin type"; else assert_eq ok ok; fi
t_end

t_begin "optin-record never writes into a state directory swapped for a link while it decides"
setup; elsewhere="$(tmpdir)"; sw="$(tmpdir)"
P2="$(tmpdir)/brg-push"; sed '$d' "$KIT/plugins/bearing/bin/brg-push" > "$P2"
# The seam's second passwd_home call is entry_for's, after any check of the
# state directory and before the write: swap the directory for a link there.
cat >> "$P2" <<EOF
passwd_home() {
  local c; c="\$(cat '$sw/n' 2>/dev/null || echo 0)"; c=\$((c+1)); echo "\$c" > '$sw/n'
  if [ "\$c" -eq 2 ]; then mv '$repo/.bearing/state' '$repo/.bearing/state.real'; ln -s '$elsewhere' '$repo/.bearing/state'; fi
  printf '%s\n' '$home'
}
main "\$@"
EOF
( cd "$repo" && bash "$P2" optin-record )
assert_eq 2 "$(cat "$sw/n")" "passwd_home calls"
assert_eq "" "$(ls -A "$elsewhere")" "nothing written through the swapped link"
assert_eq absent "$(cat "$repo/.bearing/state.real/.push-optin" 2>/dev/null || echo absent)" "the stale on was removed before deciding"
t_end

t_begin "state_write refuses a linked state directory and removes a link, not its target"
setup; elsewhere="$(tmpdir)"; victim="$(tmpdir)/v"; printf 'keep\n' > "$victim"
sfn() { ( cd "$repo" && root="$repo" bash -c '. "$1"; shift; printf "x\n" | state_write "$@"' _ "$fns" "$@" ); }
ln -s "$victim" "$repo/.bearing/state/push-result"
assert_exit 0 sfn rm push-result
assert_eq "keep" "$(cat "$victim")" "the link target survives rm"
assert_eq gone "$( [ -e "$repo/.bearing/state/push-result" ] || [ -L "$repo/.bearing/state/push-result" ] || echo gone)"
assert_exit 0 sfn put push-result
assert_eq x "$(cat "$repo/.bearing/state/push-result")"
assert_exit 1 sfn put ../escape
mv "$repo/.bearing/state" "$repo/.bearing/state.real"; ln -s "$elsewhere" "$repo/.bearing/state"
assert_exit 1 sfn put push-result
assert_exit 1 sfn rm .push-optin
assert_eq "" "$(ls -A "$elsewhere")" "nothing written into the linked directory"
t_end

t_begin "state_write judges where it is with getcwd, not the shell's idea of the path"
# The process sits in the victim (entered through a link), then the link is
# replaced by a real directory: the path string now resolves to the real state
# directory, the working directory is still the victim.
setup; victim="$(tmpdir)"; real="$(cd "$repo" && /bin/pwd -P)"
mv "$repo/.bearing/state" "$repo/.bearing/state.real"; ln -s "$victim" "$repo/.bearing/state"
assert_exit 1 bash -c '. "$1"; cd "$2/.bearing/state" && rm "$2/.bearing/state" && mkdir "$2/.bearing/state" && in_state_dir "$3"' _ "$fns" "$repo" "$real"
assert_exit 0 bash -c '. "$1"; cd "$2/.bearing/state" && in_state_dir "$3"' _ "$fns" "$repo" "$real"
t_end

t_begin "state_write never writes or deletes in a directory raced in for the state directory"
# A racer swaps .bearing/state (a link to the victim) and .bearing/D (a real
# directory) as fast as it can: renameat2 RENAME_EXCHANGE where libc has it,
# else three plain renames. No put or rm may touch the victim.
setup; victim="$(tmpdir)"; printf 'keep\n' > "$victim/push.log"
mv "$repo/.bearing/state" "$repo/.bearing/D"; ln -s "$victim" "$repo/.bearing/state"
python3 - "$repo/.bearing" 30 > /dev/null 2>&1 <<'PY' &
import os, sys, time
d = sys.argv[1]; end = time.time() + float(sys.argv[2])
a, b, t = d + "/state", d + "/D", d + "/T"
try:
    import ctypes
    swap = ctypes.CDLL(None, use_errno=True).renameat2
except Exception:
    swap = None
while time.time() < end:
    if swap is not None:
        swap(-100, a.encode(), -100, b.encode(), 2)
    else:
        try:
            os.rename(a, t); os.rename(b, a); os.rename(t, b)
        except OSError:
            pass
PY
racer=$!
refused=0; done_=0; i=0
while [ "$i" -lt 200 ]; do
  if ( cd "$repo" && root="$repo" bash -c '. "$1"; printf "x\n" | state_write put push.log' _ "$fns" ); then done_=$((done_+1)); else refused=$((refused+1)); fi
  ( cd "$repo" && root="$repo" bash -c '. "$1"; state_write rm push.log' _ "$fns" )
  i=$((i+1))
done
kill "$racer" 2>/dev/null; wait "$racer" 2>/dev/null
assert_eq "push.log" "$(ls -A "$victim")" "nothing new in the victim"
assert_eq keep "$(cat "$victim/push.log")" "the victim's file neither replaced nor deleted"
# Both states were seen, so the racer ran: some calls found the real directory, some the link.
assert_eq 1 "$([ "$refused" -gt 0 ] && [ "$done_" -gt 0 ] && echo 1)" "puts refused $refused, done $done_ of 200"
t_end

t_begin "state_write ignores CDPATH"
setup; evil="$(tmpdir)"; mkdir -p "$evil/.bearing/state" "$evil/state"
cdp() { ( cd "$repo" && CDPATH="$evil" root="$repo" bash -c '. "$1"; printf "x\n" | state_write put push-result' _ "$fns" ); }
assert_exit 0 cdp
assert_eq x "$(cat "$repo/.bearing/state/push-result" 2>/dev/null)" "written in the repository"
assert_eq "" "$(find "$evil" -type f)" "nothing written under CDPATH"
t_end

t_begin "optin-record with no .git leaves no stale on"
setup; mv "$repo/.git" "$repo/.git.away"
( cd "$repo" && bash "$P" optin-record )
assert_eq absent "$(cat "$repo/.bearing/state/.push-optin" 2>/dev/null || echo absent)"
t_end

# within <seconds> <cmd...>: exit 0 when the command ended in time, 1 when it
# had to be killed. Its output goes nowhere, so a stuck child cannot hold the
# test's pipe open.
within() {
  local s="$1" p i=0; shift
  "$@" < /dev/null > /dev/null 2>&1 & p=$!
  while kill -0 "$p" 2>/dev/null; do
    if [ "$i" -ge $((s*10)) ]; then kill "$p" 2>/dev/null; wait "$p" 2>/dev/null; return 1; fi
    sleep 0.1; i=$((i+1))
  done
  wait "$p" 2>/dev/null; return 0
}

t_begin "optin-record does not hang on a FIFO config and clears a stale on"
setup; fake="$(tmpdir)"; mkfifo "$fake/config"
mv "$repo/.git" "$repo/.git.real"; printf 'gitdir: %s\n' "$fake" > "$repo/.git"
assert_exit 0 within 10 bash -c "cd '$repo' && bash '$P' optin-record"
( exec 3<> "$fake/config" ) 2>/dev/null   # releases a reader left blocked on the FIFO
assert_eq absent "$(cat "$repo/.bearing/state/.push-optin" 2>/dev/null | grep -x on || echo absent)"
t_end

t_begin "bounded stops a command that runs past its time"
for i in 1 2 3; do assert_exit 124 bash -c '. "$1"; bounded 1 sleep 20' _ "$fns"; done
assert_exit 3 bash -c '. "$1"; bounded 5 sh -c "exit 3"' _ "$fns"
t_end

t_begin "optin-record ignores a repository above its temp directory"
setup; pt="$home/.config/bearing/tmp"; mkdir -p "$pt"
printf 'gitdir: /nonexistent\n' > "$pt/.git"   # git stops with "not a git repository" if it looks here
( cd "$repo" && bash "$P" optin-record )
rm -f "$pt/.git"
assert_eq on "$(cat "$repo/.bearing/state/.push-optin")"
t_end

t_begin "optin-record works in the protected tmp, never TMPDIR"
setup; t="$(tmpdir)"; chmod 500 "$t"; rm -f "$repo/.bearing/state/.push-optin"
( cd "$repo" && TMPDIR="$t" bash "$P" optin-record )
chmod 700 "$t"
assert_eq on "$(cat "$repo/.bearing/state/.push-optin" 2>/dev/null)"
assert_eq "" "$(ls -A "$home/.config/bearing/tmp" 2>&1)" "the protected tmp exists and holds nothing after the run"
t_end

t_begin "a tracked .bearing file changed after make check makes the gate stale"
setup; sleep 1; printf '{}\n' > "$repo/.bearing/config.json"
git -C "$repo" add .bearing/config.json; git -C "$repo" commit -q -m "chore: config [ABC-1]"
assert_exit 1 in_repo check; assert_contains "$T_OUT" "no gate: 1 of 2 file(s) newer than the last make check"
t_end

t_begin "clean fails closed when git status fails"
setup; printf 'garbage' > "$repo/.git/index"
assert_exit 1 in_repo check; assert_contains "$T_OUT" "no clean:"
t_end

t_begin "an uncommitted progress file for this task and .scratch/ files neither stale the gate nor dirty the tree"
setup; sleep 1; mkdir -p "$repo/docs/progress" "$repo/.scratch"
printf 'p\n' > "$repo/docs/progress/ABC-1.md"; printf 'm\n' > "$repo/.scratch/mr-ABC-1.md"
assert_exit 0 in_repo check
assert_contains "$T_OUT" "ok clean:"; assert_contains "$T_OUT" "ok gate: 1 file(s) compared"
t_end

t_begin "a tracked progress file changed but not committed after make check still passes"
setup; mkdir -p "$repo/docs/progress" "$repo/.scratch"
printf 'p\n' > "$repo/docs/progress/ABC-1.md"; printf 's\n' > "$repo/.scratch/notes.md"
git -C "$repo" add docs/progress/ABC-1.md .scratch/notes.md; git -C "$repo" commit -q -m "docs: progress [ABC-1]"
sleep 1; touch "$repo/.bearing/state/.check-passed"; sleep 1
printf 'q\n' >> "$repo/docs/progress/ABC-1.md"; printf 't\n' >> "$repo/.scratch/notes.md"
assert_exit 0 in_repo check
assert_contains "$T_OUT" "ok clean:"; assert_contains "$T_OUT" "ok gate: 3 file(s) compared"
t_end

t_begin "a progress file committed after make check still counts"
setup; sleep 1; mkdir -p "$repo/docs/progress"; printf 'p\n' > "$repo/docs/progress/ABC-1.md"
git -C "$repo" add docs/progress/ABC-1.md; git -C "$repo" commit -q -m "docs: progress [ABC-1]"
assert_exit 1 in_repo check; assert_contains "$T_OUT" "no gate: 1 of 2 file(s) newer than the last make check"
printf 'q\n' >> "$repo/docs/progress/ABC-1.md"
assert_exit 1 in_repo check; assert_contains "$T_OUT" "no gate: 1 of 2 file(s) newer than the last make check"
t_end

t_begin "another task's progress file, a staged progress change and other docs still count"
setup; sleep 1; mkdir -p "$repo/docs/progress"; printf 'p\n' > "$repo/docs/progress/XYZ-9.md"
assert_exit 1 in_repo check; assert_contains "$T_OUT" "no gate: 1 of 2 file(s) newer than the last make check"
setup; mkdir -p "$repo/docs/progress"; printf 'p\n' > "$repo/docs/progress/ABC-1.md"
git -C "$repo" add docs/progress/ABC-1.md; git -C "$repo" commit -q -m "docs: progress [ABC-1]"
sleep 1; touch "$repo/.bearing/state/.check-passed"; sleep 1
printf 'q\n' >> "$repo/docs/progress/ABC-1.md"; git -C "$repo" add docs/progress/ABC-1.md
assert_exit 1 in_repo check; assert_contains "$T_OUT" "no clean: 1 uncommitted change(s)"
setup; sleep 1; mkdir -p "$repo/docs/progress"; printf 'p\n' > "$repo/docs/progress/ABC-1.md.bak"
assert_exit 1 in_repo check; assert_contains "$T_OUT" "no gate: 1 of 2 file(s) newer than the last make check"
t_end

t_begin "a submodule's own filter driver never runs from check's git status"
# git status looks inside a submodule for changes and refreshes its index,
# which runs the clean filter its .git/config defines on a stat-dirty file:
# every git status brg-push runs passes --ignore-submodules=dirty.
setup; canary="$(tmpdir)"
sub="$(tmpdir)/sub"; git -C "$(tmpdir)" init -q "$sub"
git -C "$sub" config user.email t@example.com; git -C "$sub" config user.name t
printf 's\n' > "$sub/s"; printf 's filter=canary\n' > "$sub/.gitattributes"
git -C "$sub" add s .gitattributes; git -C "$sub" commit -q -m "chore: sub"
git -C "$repo" -c protocol.file.allow=always submodule -q add "$sub" sm 2>/dev/null
git -C "$repo" commit -q -m "chore: sm [ABC-1]"
git config --file "$repo/.git/modules/sm/config" filter.canary.clean "touch $canary/filter; cat"
git config --file "$repo/.git/modules/sm/config" filter.canary.smudge cat
sleep 1; touch "$repo/.bearing/state/.check-passed"; sleep 1; touch "$repo/sm/s"
assert_exit 0 in_repo check
assert_contains "$T_OUT" "ok clean: no uncommitted change"
assert_contains "$T_OUT" "push-check: 8 conditions, 8 met"
assert_eq "" "$(ls -A "$canary")" "the submodule's filter never ran"
t_end

t_summary
