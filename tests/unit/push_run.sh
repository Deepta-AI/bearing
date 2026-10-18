#!/usr/bin/env bash
# tests/unit/push_run.sh: brg-push request, run and status, and the hooks that
# drive them. request writes the request only when check passes; run, from
# the Stop hook, re-judges the request, the opt-in, the session mark, the
# gate marker and the engineer's global transport settings, then clones the
# branch fresh and pushes it to the URL listed in bearing.env, never running
# a repository hook, Makefile, git config key or exported variable; every
# file it writes in .bearing/state goes through state_write, never through a
# planted link. The Stop gate starts it when it passes, and a core.fsmonitor
# in .git/config never runs from a hook. Local bare repositories only.
# bash 3.2 safe.
set -u
. "$(dirname "$0")/../lib/assert.sh"
unset BEARING_ENV BEARING_AUTO_PUSH CLAUDE_PROJECT_DIR
home="$(tmpdir)"; mkdir -p "$home/.config/bearing"; envf="$home/.config/bearing/bearing.env"
# The whole plugin, so stop-gate finds the seamed brg-push beside the guard;
# brg-push with the passwd home pointed at the fixture: the one seam.
pb="$(tmpdir)/bearing"; cp -R "$KIT/plugins/bearing/." "$pb/"
sed '$d' "$KIT/plugins/bearing/bin/brg-push" > "$pb/bin/brg-push"
printf "passwd_home() { printf '%%s\\\\n' '%s'; }\nmain \"\$@\"\n" "$home" >> "$pb/bin/brg-push"
P="$pb/bin/brg-push"; GUARD="$pb/bin/brg-guard"
fns="$(tmpdir)/fns.sh"; sed '$d' "$P" > "$fns"

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
  rm -f "$home/.gitconfig"
  ( cd "$repo" && bash "$P" optin-record )
}
in_repo() { ( cd "$repo" && bash "$P" "$@" ) }
mark() { touch "$repo/.bearing/state/.session-s1"; }
# gcfg <key> <value>: the engineer's global git config, written from a
# directory that is no repository (a worktree's .git pointer may be unreadable).
gcfg() { ( cd "$home" && GIT_CEILING_DIRECTORIES="$home" git config --file "$home/.gitconfig" "$@" ); }
absent() { if [ -e "$1" ] || [ -L "$1" ]; then echo present; else echo absent; fi; }
canary="$(tmpdir)/canary"; mkdir -p "$canary"
none_ran() { # no canary under the fixture: no repository code ran
  assert_eq "" "$(find "$canary" -type f 2>/dev/null)" "no repository code ran"
}
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

t_begin "request needs every condition"
setup; git -C "$repo" switch -q main
assert_exit 1 in_repo request
assert_contains "$T_OUT" "push-check: 8 conditions"
assert_eq absent "$(absent "$repo/.bearing/state/push-request")" "no request written on main"
t_end

t_begin "request then run --foreground pushes the branch from a clone and nothing else"
setup; git -C "$repo" tag v9.9.9; sleep 1; mark
assert_exit 0 in_repo request
assert_contains "$T_OUT" "push: requested feature/ABC-1-Thing $(git -C "$repo" rev-parse --short HEAD)"
assert_contains "$(cat "$repo/.bearing/state/push-request")" "sha=$(git -C "$repo" rev-parse HEAD)"
assert_exit 0 in_repo run --id s1 --foreground
assert_contains "$T_OUT" "push-run: 8 conditions, 8 met"
assert_eq "$(git -C "$repo" rev-parse HEAD)" "$(git -C "$remote" rev-parse refs/heads/feature/ABC-1-Thing)"
assert_eq "" "$(git -C "$remote" tag)" "no tag reached the remote"
assert_eq "refs/heads/feature/ABC-1-Thing refs/heads/main" "$(git -C "$remote" for-each-ref --format='%(refname)' | sort | tr '\n' ' ' | sed 's/ $//')" "one branch added"
assert_contains "$(cat "$repo/.bearing/state/push-result")" "pushed feature/ABC-1-Thing $(git -C "$repo" rev-parse HEAD) to localhost/"
assert_not_contains "$(cat "$repo/.bearing/state/push-result" "$repo/.bearing/state/push.log" 2>/dev/null)" "file://"
assert_contains "$(cat "$repo/.bearing/state/push.log")" "push-run: 8 conditions, 8 met"
assert_eq "" "$(git -C "$repo" config --get branch.feature/ABC-1-Thing.remote)" "no upstream set in the working repository"
assert_eq absent "$(absent "$repo/.bearing/state/push-request")" "request consumed"
assert_contains "$(cat "$repo/.bearing/state/gates.log" 2>/dev/null)" "	push	pushed	"
t_end

t_begin "no repository hook, Makefile, git config or exported variable runs at push time"
setup
printf 'check:\n\t@touch %s/make\n\t@mkdir -p .bearing/state && touch .bearing/state/.check-passed\n' "$canary" > "$repo/Makefile"; git -C "$repo" commit -q -am "chore: m [ABC-1]"
sleep 1; touch "$repo/.bearing/state/.check-passed"; mark; in_repo request >/dev/null
# The traps go in after the request: request runs in the sandbox, where they are harmless.
mkdir -p "$repo/.githooks"; cp -R "$KIT/plugins/bearing/templates/repo/.githooks/." "$repo/.githooks/"
for h in pre-push lib.sh; do printf '\ntouch %s/hook-%s\n' "$canary" "$h" >> "$repo/.githooks/$h"; done
git -C "$repo" config core.hooksPath .githooks
git -C "$repo" config core.sshCommand "touch $canary/sshcommand; ssh"
git -C "$repo" config credential.helper "!touch $canary/credential"
git -C "$repo" config core.fsmonitor "touch $canary/fsmonitor"
git -C "$repo" config core.alternateRefsCommand "touch $canary/alternaterefs"
git -C "$repo" config uploadpack.packObjectsHook "touch $canary/packobjectshook"
git -C "$repo" config core.pager "touch $canary/pager"
alt="$(tmpdir)/alt.git"; git init -q --bare "$alt"; printf '%s/objects\n' "$alt" > "$repo/.git/objects/info/alternates"
evil="$(tmpdir)/evil.git"; git init -q --bare "$evil"
git -C "$repo" config "url.file://$evil.pushInsteadOf" "file://$remote"
git -C "$repo" config "url.file://$evil.insteadOf" "file://$remote"
assert_exit 0 bash -c "cd '$repo' && GIT_SSH_COMMAND='touch $canary/env' GIT_CONFIG_PARAMETERS=\"'core.hooksPath'='.githooks'\" GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.sshCommand GIT_CONFIG_VALUE_0='touch $canary/env2' GIT_DIR=/nonexistent bash '$P' run --id s1 --foreground"
assert_contains "$T_OUT" "push-run: 8 conditions, 8 met"
assert_eq "$(git -C "$repo" rev-parse HEAD)" "$(git -C "$remote" rev-parse refs/heads/feature/ABC-1-Thing)" "landed at the listed entry"
assert_eq "" "$(git --git-dir="$evil" for-each-ref)" "nothing reached the insteadOf target"
none_ran
t_end

t_begin "the temporary clone is removed, pushed or refused"
pt="$home/.config/bearing/tmp"
setup; sleep 1; mark; in_repo request >/dev/null
t="$(tmpdir)"; ( cd "$repo" && TMPDIR="$t" bash "$P" run --id s1 --foreground >/dev/null )
assert_eq "" "$(ls -A "$t")" "nothing in TMPDIR after a push"
assert_eq "" "$(ls -A "$pt" 2>/dev/null)" "nothing left in the protected tmp after a push"
setup; sleep 1; mark; in_repo request >/dev/null; git -C "$repo" commit -q --allow-empty -m "chore: later [ABC-1]"
t="$(tmpdir)"; ( cd "$repo" && TMPDIR="$t" bash "$P" run --id s1 --foreground >/dev/null )
assert_eq "" "$(ls -A "$t")" "nothing in TMPDIR after a refusal"
assert_eq "" "$(ls -A "$pt" 2>/dev/null)" "nothing left in the protected tmp after a refusal"
t_end

t_begin "run refuses a request for another sha"
setup; sleep 1; mark; in_repo request >/dev/null
git -C "$repo" commit -q --allow-empty -m "chore: later [ABC-1]"; touch "$repo/.bearing/state/.check-passed"
assert_exit 1 in_repo run --id s1 --foreground
assert_contains "$T_OUT" "no clone:"
assert_eq "" "$(git -C "$remote" branch --list 'feature/*')" "nothing pushed"
assert_eq absent "$(absent "$repo/.bearing/state/push-request")" "refused request deleted"
assert_contains "$(cat "$repo/.bearing/state/push-result")" "push refused: clone"
assert_contains "$(cat "$repo/.bearing/state/gates.log" 2>/dev/null)" "	push	refused	"
t_end

t_begin "run refuses a request naming a protected or non-task branch, before any clone"
for b in main release/v1.2.0 '--upload-pack=touch' feature/x 'feature/ABC-1-Thing
branch=main'; do
  setup; sleep 1; mark
  printf 'branch=%s\nsha=%s\ntime=t\n' "$b" "$(git -C "$repo" rev-parse HEAD)" > "$repo/.bearing/state/push-request"
  assert_exit 1 in_repo run --id s1 --foreground
  assert_contains "$T_OUT" "no branch:" "$b"
  assert_eq "" "$(git -C "$remote" for-each-ref 'refs/heads/feature/*' 'refs/heads/release/*')" "nothing pushed for $b"
done
t_end

t_begin "run refuses a branch listed in PROTECTED_BRANCHES and a malformed sha"
setup; sleep 1; mark; mkdir -p "$repo/.githooks"
printf "PROTECTED_BRANCHES='main feature/ABC-1-Thing'\n" > "$repo/.githooks/lib.sh"
in_repo request >/dev/null
assert_exit 1 in_repo run --id s1 --foreground
assert_contains "$T_OUT" "no not-protected:"
setup; sleep 1; mark
printf 'branch=feature/ABC-1-Thing\nsha=HEAD\n' > "$repo/.bearing/state/push-request"
assert_exit 1 in_repo run --id s1 --foreground
assert_contains "$T_OUT" "no request:"
assert_eq "" "$(git -C "$remote" branch --list 'feature/*')" "nothing pushed"
t_end

t_begin "origin re-pointed at an unlisted URL pushes nothing"
setup; sleep 1; mark; in_repo request >/dev/null
git -C "$repo" remote set-url origin git@git.example.test:other/repo.git
assert_exit 1 in_repo run --id s1 --foreground
assert_contains "$T_OUT" "no opt-in:"
assert_eq "" "$(git -C "$remote" branch --list 'feature/*')" "nothing pushed"
t_end

t_begin "a redirecting setting in the engineer's global git config refuses, naming it"
for kv in "core.sshCommand=ssh -p 2222" "core.gitProxy=touch-proxy" "http.proxy=http://p.example.test:3128" \
          "https.proxy=http://p.example.test:3128" "http.https://git.example.test/.proxy=http://p.example.test:3128" \
          "http.curloptResolve=git.example.test:443:203.0.113.9" "http.sslVerify=false" \
          "http.https://git.example.test/.sslVerify=false" "url.file:///x.pushInsteadOf=file://" "url.file:///x.insteadOf=file:///"; do
  setup; sleep 1; mark; in_repo request >/dev/null
  gcfg "${kv%%=*}" "${kv#*=}"
  assert_exit 1 in_repo run --id s1 --foreground
  assert_contains "$T_OUT" "no transport: $(printf '%s' "${kv%%=*}" | tr 'A-Z' 'a-z')"
  assert_eq "" "$(git -C "$remote" branch --list 'feature/*')" "nothing pushed with ${kv%%=*}"
done
t_end

t_begin "a redirect the global config includes only inside the clone refuses"
setup; sleep 1; mark; in_repo request >/dev/null
printf '[core]\n\tsshCommand = ssh -p 2222\n' > "$home/.gitconfig-branch"
gcfg 'includeIf.onbranch:feature/**.path' "$home/.gitconfig-branch"
assert_exit 1 in_repo run --id s1 --foreground
assert_contains "$T_OUT" "ok transport:"
assert_contains "$T_OUT" "no clone: core.sshcommand"
assert_eq "" "$(git -C "$remote" branch --list 'feature/*')" "nothing pushed"
t_end

t_begin "settings that do not redirect this push are allowed"
setup; sleep 1; mark; in_repo request >/dev/null
gcfg url.git@other.example.test:.insteadOf https://other.example.test/
gcfg http.sslVerify true
gcfg core.sshCommand ssh
assert_exit 0 in_repo run --id s1 --foreground
assert_contains "$T_OUT" "ok transport:"
t_end

t_begin "run refuses an opt-in written during the session"
setup; mark; sleep 1; printf 'BEARING_AUTO_PUSH="file://%s"\n' "$remote" > "$envf"; in_repo request >/dev/null
assert_exit 1 in_repo run --id s1 --foreground
assert_contains "$T_OUT" "no opt-in-age:"
setup; in_repo request >/dev/null
assert_exit 1 in_repo run --id s1 --foreground
assert_contains "$T_OUT" "no opt-in-age:" "no session mark"
setup; sleep 1; mark; in_repo request >/dev/null
assert_exit 1 in_repo run --id ../s1 --foreground
assert_contains "$T_OUT" "no opt-in-age:" "a session id that is not a plain name"
t_end

t_begin "run needs the gate marker and an environment-free opt-in"
setup; sleep 1; mark; in_repo request >/dev/null; rm -f "$repo/.bearing/state/.check-passed"
assert_exit 1 in_repo run --id s1 --foreground
assert_contains "$T_OUT" "no marker:"
setup; sleep 1; mark; in_repo request >/dev/null; : > "$envf"; touch -r "$repo/.bearing/state/.check-passed" "$envf"
assert_exit 1 bash -c "cd '$repo' && BEARING_AUTO_PUSH='file://$remote' BEARING_ENV=/dev/null bash '$P' run --id s1 --foreground"
assert_contains "$T_OUT" "no opt-in:"
assert_eq "" "$(git -C "$remote" branch --list 'feature/*')" "nothing pushed"
t_end

t_begin "run without a request pushes nothing"
setup; sleep 1; mark
assert_exit 1 in_repo run --id s1 --foreground
assert_contains "$T_OUT" "no request: none"
assert_eq absent "$(absent "$repo/.bearing/state/push-result")" "no result for a request never made"
t_end

t_begin "run never writes through a link planted in the state directory"
setup; sleep 1; mark; in_repo request >/dev/null
v="$(tmpdir)"
for f in push-result push.log gates.log; do printf 'keep\n' > "$v/$f"; ln -s "$v/$f" "$repo/.bearing/state/$f"; done
assert_exit 0 in_repo run --id s1 --foreground
for f in push-result push.log gates.log; do assert_eq keep "$(cat "$v/$f")" "$f target untouched"; done
assert_contains "$(cat "$repo/.bearing/state/push-result")" "pushed feature/ABC-1-Thing"
assert_not_contains "$(cat "$repo/.bearing/state/gates.log" "$repo/.bearing/state/push.log")" "keep" "no linked content read back"
t_end

t_begin "run never appends to a hard-linked log and never reads a hard-linked or linked request"
setup; sleep 1; mark; in_repo request >/dev/null
v="$(tmpdir)"; printf 'secret\n' > "$v/log"
rm -f "$repo/.bearing/state/gates.log"; ln "$v/log" "$repo/.bearing/state/gates.log"
assert_exit 0 in_repo run --id s1 --foreground
assert_eq secret "$(cat "$v/log")" "the hard-linked file is unchanged"
setup; sleep 1; mark; in_repo request >/dev/null
mv "$repo/.bearing/state/push-request" "$v/req"; ln -s "$v/req" "$repo/.bearing/state/push-request"
assert_exit 1 in_repo run --id s1 --foreground
assert_contains "$T_OUT" "no request:"
assert_eq "" "$(git -C "$remote" branch --list 'feature/*')" "nothing pushed from a linked request"
t_end

t_begin "a FIFO in place of the request does not hang run"
setup; sleep 1; mark; mkfifo "$repo/.bearing/state/push-request"
assert_exit 0 within 10 bash -c "cd '$repo' && bash '$P' run --id s1 --foreground"
( exec 3<> "$repo/.bearing/state/push-request" ) 2>/dev/null
t_end

t_begin "status prints the result once with --unseen"
setup
assert_exit 0 in_repo status; assert_eq "push: none" "$T_OUT"
sleep 1; mark; in_repo request >/dev/null; in_repo run --id s1 --foreground >/dev/null
assert_exit 0 in_repo status --unseen; assert_contains "$T_OUT" "bearing push: pushed feature/ABC-1-Thing"
assert_exit 0 in_repo status --unseen; assert_eq "" "$T_OUT"
assert_exit 0 in_repo status; assert_contains "$T_OUT" "pushed feature/ABC-1-Thing"
t_end

t_begin "an entry's credentials never reach a file run writes"
assert_eq "To localhost/g/r" "$(printf 'To https://u:tok@git.example.test/g/r.git\n' | bash -c '. "$1"; redact "$2" localhost/g/r' _ "$fns" 'https://u:tok@git.example.test/g/r.git')"
assert_eq "x https://git.example.test/y" "$(printf 'x https://u:tok@git.example.test/y\n' | bash -c '. "$1"; redact "$2" k' _ "$fns" 'https://other')"
t_end

t_begin "the stop gate runs a requested push when it passes"
setup; sleep 1; mark; in_repo request >/dev/null
assert_exit 0 bash -c "cd '$repo' && bash '$GUARD' stop-gate --id s1"
assert_contains "$T_OUT" "bearing push: started for feature/ABC-1-Thing"
for i in 1 2 3 4 5 6 7 8 9 10; do [ -f "$repo/.bearing/state/push-result" ] && break; sleep 1; done
assert_contains "$(cat "$repo/.bearing/state/push-result")" "pushed feature/ABC-1-Thing"
assert_contains "$(cat "$repo/.bearing/state/push.log")" "push started"
assert_eq "$(git -C "$repo" rev-parse HEAD)" "$(git -C "$remote" rev-parse refs/heads/feature/ABC-1-Thing)"
t_end

t_begin "a vendored guard called by a relative path from a subdirectory still runs the push"
setup; sleep 1; mark; in_repo request >/dev/null
mkdir -p "$repo/.bearing/bin" "$repo/sub"; cp -R "$pb/bin/." "$repo/.bearing/bin/"
printf '.bearing/bin/\nsub/\n' >> "$repo/.git/info/exclude"
assert_exit 0 bash -c "cd '$repo/sub' && bash ../.bearing/bin/brg-guard stop-gate --id s1"
assert_contains "$T_OUT" "bearing push: started for feature/ABC-1-Thing"
for i in 1 2 3 4 5 6 7 8 9 10; do [ -f "$repo/.bearing/state/push-result" ] && break; sleep 1; done
assert_contains "$(cat "$repo/.bearing/state/push-result" 2>/dev/null)" "pushed feature/ABC-1-Thing"
t_end

t_begin "the Stop hook returns while the push runs in the background"
setup; sleep 1; mark; in_repo request >/dev/null
printf '{"session_id":"s1","stop_hook_active":false}' > "$repo/.bearing/state/stop.json"
assert_exit 0 within 10 bash -c "cd '$repo' && bash '$pb/hooks/scripts/stop-summary.sh' < .bearing/state/stop.json"
for i in 1 2 3 4 5 6 7 8 9 10; do [ -f "$repo/.bearing/state/push-result" ] && break; sleep 1; done
assert_contains "$(cat "$repo/.bearing/state/push-result" 2>/dev/null)" "pushed feature/ABC-1-Thing"
t_end

t_begin "a blocked stop gate never pushes"
setup; sleep 1; mark; in_repo request >/dev/null; sleep 1; printf 'dirty\n' > "$repo/b.txt"
assert_exit 2 bash -c "cd '$repo' && bash '$GUARD' stop-gate --id s1"
sleep 2; assert_eq "" "$(git -C "$remote" branch --list 'feature/*')" "nothing pushed"
assert_eq present "$(absent "$repo/.bearing/state/push-request")" "the request waits for a stop that passes"
t_end

t_begin "session and task-id print an unseen result once"
setup; sleep 1; mark; in_repo request >/dev/null; in_repo run --id s1 --foreground >/dev/null
assert_exit 0 bash -c "cd '$repo' && bash '$GUARD' task-id 'go on'"
assert_contains "$T_OUT" "bearing push: pushed feature/ABC-1-Thing"
assert_exit 0 bash -c "cd '$repo' && bash '$GUARD' task-id 'go on'"
assert_not_contains "$T_OUT" "bearing push:"
setup; sleep 1; mark; in_repo request >/dev/null; in_repo run --id s1 --foreground >/dev/null
rm -f "$repo/.bearing/state/.push-optin"
assert_exit 0 bash -c "cd '$repo' && bash '$GUARD' session --id s2 --source startup"
assert_contains "$T_OUT" "bearing push: pushed feature/ABC-1-Thing"
assert_eq on "$(cat "$repo/.bearing/state/.push-optin" 2>/dev/null)" "session records the opt-in"
t_end

t_begin "a core.fsmonitor in .git/config never runs from the Stop or SessionStart hooks"
setup; sleep 1; mark; printf 'dirty\n' > "$repo/c.txt"
git -C "$repo" config core.fsmonitor "touch $canary/fsmonitor-hook"
printf '{"session_id":"s1","source":"startup","stop_hook_active":false}' > "$repo/.bearing/state/hook.json"
( cd "$repo" && bash "$pb/hooks/scripts/stop-summary.sh" < .bearing/state/hook.json ) >/dev/null 2>&1
( cd "$repo" && bash "$pb/hooks/scripts/session-start.sh" < .bearing/state/hook.json ) >/dev/null 2>&1
( cd "$repo" && bash "$pb/hooks/scripts/precompact.sh" < .bearing/state/hook.json ) >/dev/null 2>&1
( cd "$repo" && bash "$pb/hooks/scripts/session-end.sh" < .bearing/state/hook.json ) >/dev/null 2>&1
( cd "$repo" && bash "$GUARD" stop-gate --id s1 ) >/dev/null 2>&1
none_ran
t_end

t_begin "a repository hook never runs from the Stop or SessionStart hooks"
# git status refreshes the index and runs post-index-change from core.hooksPath
# or .git/hooks; the hooks pin core.hooksPath=/dev/null for every git they start.
setup; sleep 1; mark; printf 'dirty\n' > "$repo/c.txt"
mkdir -p "$repo/tools"; printf 'tools/\n' >> "$repo/.git/info/exclude"
for d in "$repo/tools" "$repo/.git/hooks"; do
  printf '#!/bin/sh\ntouch "%s/post-index-change-$$"\n' "$canary" > "$d/post-index-change"; chmod +x "$d/post-index-change"
done
printf '{"session_id":"s1","source":"startup","stop_hook_active":false}' > "$repo/.bearing/state/hook.json"
for hooks in tools .git/hooks; do
  git -C "$repo" config core.hooksPath "$hooks"
  sleep 1; touch "$repo/a.txt"; ( cd "$repo" && bash "$GUARD" session --id s1 --source startup ) >/dev/null 2>&1
  sleep 1; touch "$repo/a.txt"; ( cd "$repo" && bash "$pb/hooks/scripts/stop-summary.sh" < .bearing/state/hook.json ) >/dev/null 2>&1
  sleep 1; touch "$repo/a.txt"; ( cd "$repo" && bash "$pb/hooks/scripts/session-start.sh" < .bearing/state/hook.json ) >/dev/null 2>&1
  sleep 1; touch "$repo/a.txt"; ( cd "$repo" && bash "$GUARD" stop-gate --id s1 ) >/dev/null 2>&1
done
assert_eq 0 "$(find "$canary" -type f | wc -l | tr -d ' ')" "repository hook runs from the guard session, stop-summary.sh, session-start.sh and stop-gate"
rm -f "$canary"/*
t_end

t_begin "every hook script sources lib.sh, and lib.sh and the guard turn core.fsmonitor and repository hooks off"
n=0
for f in "$KIT"/plugins/bearing/hooks/scripts/*.sh; do
  [ "${f##*/}" = lib.sh ] && continue
  n=$((n+1))
  assert_contains "$(cat "$f")" '. "$(dirname "$0")/lib.sh"' "${f##*/} sources lib.sh"
done
assert_eq 1 "$([ "$n" -ge 7 ] && echo 1)" "hook scripts checked: $n"
assert_contains "$(cat "$KIT/plugins/bearing/hooks/scripts/lib.sh")" "'core.fsmonitor=false' 'core.hooksPath=/dev/null'"
assert_contains "$(cat "$KIT/plugins/bearing/bin/brg-guard")" "'core.fsmonitor=false' 'core.hooksPath=/dev/null'"
t_end

t_begin "the clone lives in a mode 700 directory under the passwd home, never TMPDIR"
# A process that can write TMPDIR (the sandbox can) watches for the clone and
# writes a push URL and a receive-pack command into its config.
setup; sleep 1; mark; in_repo request >/dev/null
pt="$home/.config/bearing/tmp"; rm -rf "$pt"; mkdir -m 755 "$pt"
evil="$(tmpdir)/evil.git"; git init -q --bare "$evil"; t="$(tmpdir)"; found="$(tmpdir)/found"
( end=$(( $(date +%s) + 30 ))
  while [ "$(date +%s)" -lt "$end" ] && [ ! -f "$t/stop" ]; do
    for c in "$t"/*/c/.git/config "$t"/*/*/.git/config; do
      [ -f "$c" ] || continue
      printf '[remote "file://%s"]\n\tpushurl = file://%s\n\treceivepack = touch %s/receivepack; git-receive-pack\n' "$remote" "$evil" "$canary" >> "$c"
      touch "$found"; exit 0
    done
  done ) & wpid=$!
assert_exit 0 bash -c "cd '$repo' && TMPDIR='$t' bash '$P' run --id s1 --foreground"
touch "$t/stop"; wait "$wpid"
assert_contains "$T_OUT" "push-run: 8 conditions, 8 met"
assert_eq absent "$(absent "$found")" "no clone in TMPDIR to write to"
assert_eq "$(git -C "$repo" rev-parse HEAD)" "$(git -C "$remote" rev-parse refs/heads/feature/ABC-1-Thing)" "landed at the listed entry"
assert_eq "" "$(git --git-dir="$evil" for-each-ref)" "nothing reached the written URL"
assert_eq drwx------ "$(ls -ld "$pt" | cut -c1-10)" "the protected tmp is mode 700"
none_ran
t_end

t_begin "a clone config holding anything git clone did not write is refused before the push"
cl="$(tmpdir)"; r="$(tmpdir)/r"; git init -q -b main "$r"
git -C "$r" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m i; git -C "$r" switch -q -c feature/ABC-1-Thing
git clone -q --no-local --single-branch --branch feature/ABC-1-Thing --no-tags --no-checkout -- "$r" "$cl/c"
cce() { bash -c '. "$1"; tmp="$2"; root="$3"; b=feature/ABC-1-Thing; home="$4"; clone_config_extra; rc=$?; echo "keys=$ckeys"; exit $rc' _ "$fns" "$cl" "$r" "$home"; }
assert_exit 1 cce
assert_eq 1 "$(printf '%s\n' "$T_OUT" | sed -n 's/^keys=//p' | awk '$1 >= 9 { print 1 }')" "9 or more keys as clone wrote them: $T_OUT"
for kv in "remote.file:///x.pushurl=file:///evil" "remote.file:///x.receivepack=touch x" "remote.origin.pushurl=file:///evil" \
          "include.path=/tmp/x" "core.sshCommand=touch x" "branch.main.remote=origin" "url.file:///evil.pushInsteadOf=file:///x"; do
  cp "$cl/c/.git/config" "$cl/keep"
  ( cd "$cl" && GIT_CEILING_DIRECTORIES="$cl" git config --file "$cl/c/.git/config" "${kv%%=*}" "${kv#*=}" )
  assert_exit 0 cce
  assert_contains "$T_OUT" "$(printf '%s' "${kv%%=*}" | tr 'A-Z' 'a-z')"
  cp "$cl/keep" "$cl/c/.git/config"
done
: > "$cl/c/.git/config"
assert_exit 0 cce; assert_contains "$T_OUT" "no config keys"
t_end

t_begin "a global remote section named by the entry URL refuses, naming the key"
for v in pushurl url receivepack push; do
  setup; sleep 1; mark; in_repo request >/dev/null
  evil="$(tmpdir)/evil.git"; git init -q --bare "$evil"
  gcfg "remote.file://$remote.$v" "file://$evil"
  assert_exit 1 in_repo run --id s1 --foreground
  assert_contains "$T_OUT" "no transport: remote.<entry>.$v"
  assert_not_contains "$T_OUT" "file://$remote"
  assert_eq "" "$(git -C "$remote" branch --list 'feature/*')" "nothing pushed with remote.<entry>.$v"
  assert_eq "" "$(git --git-dir="$evil" for-each-ref)" "nothing at the pushurl with remote.<entry>.$v"
done
t_end

t_begin "the clone and the push read no system or global git config but the credential keys"
setup; sleep 1; mark; in_repo request >/dev/null
gcfg protocol.file.allow never
gcfg push.followTags true
gcfg credential.helper store
assert_exit 0 in_repo run --id s1 --foreground
assert_contains "$T_OUT" "push-run: 8 conditions, 8 met"
assert_eq "$(git -C "$repo" rev-parse HEAD)" "$(git -C "$remote" rev-parse refs/heads/feature/ABC-1-Thing 2>/dev/null)" "pushed although the global config forbids file://"
gt="$(tmpdir)"; rm -f "$home/.gitconfig"
gcfg credential.helper "cache --timeout=60"; gcfg --add credential.helper ""; gcfg credential.https://git.example.test/g.username u
gcfg user.name n; gcfg url.file:///evil.insteadOf file:///x; gcfg protocol.file.allow never
assert_exit 0 bash -c '. "$1"; home="$2"; tmp="$3"; gen_global "$3/global"' _ "$fns" "$home" "$gt"
assert_eq "credential.helper=cache --timeout=60|credential.helper=|credential.https://git.example.test/g.username=u|" \
  "$(cd "$gt" && GIT_CEILING_DIRECTORIES="$gt" git config --file "$gt/global" --list | tr '\n' '|')" "only the credential keys"
rm -f "$home/.gitconfig"
t_end

t_summary
