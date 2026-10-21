#!/usr/bin/env bash
# tests/unit/hook_hardening.sh: the hooks run outside the sandbox, while the
# working tree (Makefile, node_modules, .git/config, .gitattributes,
# .bearing/state) is the agent's to write. So: the edit hook runs no
# repository command (no make check-file, no node_modules binary, nothing
# from the inherited PATH) and says what it did not run; every gates.log
# append refuses a planted link, hard link or FIFO and caps the label; and
# every git a hook starts runs no filter driver, external diff, pager or
# signature program the repository configures. Canary files prove nothing
# ran. bash 3.2 safe.
set -u
. "$(dirname "$0")/../lib/assert.sh"
HS="$KIT/plugins/bearing/hooks/scripts"
canary="$(tmpdir)/canary"; mkdir -p "$canary"
none_ran() { # none_ran <what>: no canary file, so no repository code ran
  assert_eq "" "$(find "$canary" -type f 2>/dev/null | sed 's#.*/##' | tr '\n' ' ')" "$1"
  rm -f "$canary"/*
}
# within <seconds> <cmd...>: 0 when the command ended in time, 1 when it had to be killed.
within() {
  local s="$1" p i=0; shift
  "$@" < /dev/null > /dev/null 2>&1 & p=$!
  while kill -0 "$p" 2>/dev/null; do
    if [ "$i" -ge $((s*10)) ]; then kill "$p" 2>/dev/null; wait "$p" 2>/dev/null; return 1; fi
    sleep 0.1; i=$((i+1))
  done
  wait "$p" 2>/dev/null; return 0
}
newrepo() { # repo: a Bearing repository on feature/ABC-1-thing, one commit ahead of main
  repo="$(tmpdir)"
  git -C "$repo" init -q -b main
  git -C "$repo" config user.email t@example.com; git -C "$repo" config user.name t
  printf '.bearing/state/\n' > "$repo/.gitignore"
  printf 'check:\n\t@mkdir -p .bearing/state && touch .bearing/state/.check-passed\n' > "$repo/Makefile"
  printf 'a\n' > "$repo/f.txt"
  git -C "$repo" add .gitignore Makefile f.txt; git -C "$repo" commit -q -m "chore: init"
  git -C "$repo" switch -q -c feature/ABC-1-thing
  mkdir -p "$repo/.bearing/state"
}
hook() { # hook <script> <json>: one Claude Code hook script, from the repository root
  printf '%s' "$2" > "$canary.in"
  ( cd "$repo" && bash "$HS/$1" < "$canary.in" ) >/dev/null 2>&1
}
guard() { ( cd "$repo" && bash "$GUARD" "$@" ) < /dev/null >/dev/null 2>&1; }

# ---------------------------------------------------------------- edit hook
t_begin "the edit hook never runs the repository's make check-file"
newrepo
printf 'check-file:\n\t@touch %s/make-check-file\nformat:\n\t@touch %s/make-format\n' "$canary" "$canary" >> "$repo/Makefile"
printf '{"a": 1}\n' > "$repo/a.json"; printf 'x = 1\n' > "$repo/a.py"; printf 'echo hi\n' > "$repo/a.sh"
for f in a.json a.py a.sh; do
  T_IN="{\"tool_input\":{\"file_path\":\"$repo/$f\"}}"
  assert_exit 0 bash -c "cd '$repo' && bash '$HS/format-file.sh' 2>/dev/null"
  assert_contains "$T_OUT" "check-file: not run by the hook" "$f: says what it did not run"
  assert_contains "$T_OUT" "make check-file FILE=$f in the session" "$f: names the session command"
done
none_ran "make check-file from the edit hook"
assert_exit 0 bash "$GUARD" check-file "$repo/a.json"
assert_exit 0 bash -c "cd '$repo' && bash '$GUARD' check-file a.py"
none_ran "make check-file from brg-guard check-file"
T_IN=''
t_end

t_begin "without a check-file target the hook still says it ran no check"
newrepo; printf '{"a": 1,}\n' > "$repo/bad.json"
T_IN="{\"tool_input\":{\"file_path\":\"$repo/bad.json\"}}"
assert_exit 0 bash -c "cd '$repo' && bash '$HS/format-file.sh' 2>/dev/null"
assert_contains "$T_OUT" "check-file: not run by the hook"
assert_not_contains "$T_OUT" '"decision"' "nothing to block on: no check ran"
T_IN=''
t_end

t_begin "the formatter never comes from node_modules, the inherited PATH or uv run"
newrepo
evil="$(tmpdir)"
for t in prettier ruff uv gofmt shfmt ktlint swiftformat terraform node npx; do
  printf '#!/bin/sh\ntouch %s/path-%s\n' "$canary" "$t" > "$evil/$t"; chmod 755 "$evil/$t"
done
mkdir -p "$repo/node_modules/.bin"
printf '#!/bin/sh\ntouch %s/node-modules-prettier\n' "$canary" > "$repo/node_modules/.bin/prettier"
chmod 755 "$repo/node_modules/.bin/prettier"
printf '[project]\nname = "x"\n' > "$repo/pyproject.toml"
for f in app.ts a.py main.go a.sh a.kt a.swift a.tf; do
  printf 'x\n' > "$repo/$f"
  ( cd "$repo" && PATH="$evil:$PATH" bash "$GUARD" format "$repo/$f" ) >/dev/null 2>&1
done
none_ran "a formatter from node_modules or the PATH the hook inherited"
t_end

# ----------------------------------------------------------------- gates.log
t_begin "a gates.log link is never followed"
newrepo; out="$(tmpdir)"
printf 'secret\n' > "$out/kept"
ln -s "$out/kept" "$repo/.bearing/state/gates.log"
guard command "ls"
assert_eq "secret" "$(cat "$out/kept")" "the link's target is unchanged"
rm -f "$repo/.bearing/state/gates.log"; ln -s "$out/made" "$repo/.bearing/state/gates.log"
guard command "ls"
assert_eq "absent" "$([ -e "$out/made" ] && echo present || echo absent)" "no file made through the link"
assert_eq 1 "$([ -f "$repo/.bearing/state/gates.log" ] && [ ! -L "$repo/.bearing/state/gates.log" ] && echo 1)" "a fresh log took the link's place"
assert_contains "$(cat "$repo/.bearing/state/gates.log")" "command	allowed"
t_end

t_begin "a gates.log hard link and a linked state directory are never written through"
newrepo; out="$(tmpdir)"
printf 'secret\n' > "$out/hard"; ln "$out/hard" "$repo/.bearing/state/gates.log"
guard command "ls"
assert_eq "secret" "$(cat "$out/hard")" "the hard link's other name is unchanged"
rm -rf "$repo/.bearing/state"; mkdir "$out/state"; ln -s "$out/state" "$repo/.bearing/state"
guard command "ls"
hook session-end.sh '{"session_id":"s1"}'
hook precompact.sh '{"session_id":"s1","trigger":"auto"}'
assert_eq "absent" "$([ -e "$out/state/gates.log" ] && echo present || echo absent)" "no gates.log in the linked directory"
t_end

t_begin "a gates.log FIFO never hangs a hook"
newrepo; mkfifo "$repo/.bearing/state/gates.log"
assert_eq 0 "$(within 8 guard command "ls"; echo $?)" "the guard's append returns"
rm -f "$repo/.bearing/state/gates.log"; mkfifo "$repo/.bearing/state/gates.log"
assert_eq 0 "$(within 8 hook precompact.sh '{"session_id":"s1","trigger":"auto"}'; echo $?)" "brg-session's and the guard's appends return"
rm -f "$repo/.bearing/state/gates.log"; mkfifo "$repo/.bearing/state/gates.log"
assert_eq 0 "$(within 8 hook session-end.sh '{"session_id":"s1"}'; echo $?)" "session-end's append returns"
t_end

t_begin "the label a gate records is capped and holds no control character"
newrepo
ext="e$(printf '\033')[31m$(printf '%0200d' 0)"
printf 'x\n' > "$repo/a.$ext"
guard format "$repo/a.$ext"
line="$(grep '	format	' "$repo/.bearing/state/gates.log")"
assert_eq 1 "$(printf '%s\n' "$line" | wc -l | tr -d ' ')" "one format line"
assert_not_contains "$line" "$(printf '\033')" "no escape character"
assert_eq 1 "$([ "$(printf '%s' "$line" | cut -f5 | tr -d '\n' | wc -c | tr -d ' ')" -le 120 ] && echo 1)" "the label is 120 bytes at most"
assert_eq 5 "$(printf '%s' "$line" | awk -F'\t' '{print NF}')" "five fields"
t_end

# ----------------------------------------------------------------------- git
# A tracked file whose .gitattributes names filter drivers the repository's
# .git/config defines, a submodule with its own filter, a signed commit with
# log.showSignature on, an external diff and a pager. Each runs a canary.
gitrepo() {
  newrepo
  printf '*.txt filter=evil\n*.dat filter=evproc\n' > "$repo/.gitattributes"
  printf 'p\n' > "$repo/p.dat"
  git -C "$repo" -c filter.evil.clean=cat add .gitattributes p.dat f.txt
  git -C "$repo" commit -q -m "chore: attributes [ABC-1]"
  sub0="$(tmpdir)"; git -C "$sub0" init -q -b main
  printf '*.txt filter=subevil\n' > "$sub0/.gitattributes"; printf 's\n' > "$sub0/s.txt"
  git -C "$sub0" add .gitattributes s.txt; git -C "$sub0" -c user.email=t@example.com -c user.name=t commit -q -m init
  git clone -q "$sub0" "$repo/sub"
  printf '[submodule "sub"]\n\tpath = sub\n\turl = ../sub0\n\tignore = none\n' > "$repo/.gitmodules"
  git -C "$repo" add .gitmodules sub 2>/dev/null; git -C "$repo" commit -q -m "chore: sub [ABC-1]"
  t="$(git -C "$repo" rev-parse 'HEAD^{tree}')"; p="$(git -C "$repo" rev-parse HEAD)"
  c="$(printf 'tree %s\nparent %s\nauthor t <t@example.com> 1 +0000\ncommitter t <t@example.com> 1 +0000\ngpgsig -----BEGIN PGP SIGNATURE-----\n \n x\n -----END PGP SIGNATURE-----\n\nfeat: signed [ABC-1]\n' "$t" "$p" | git -C "$repo" hash-object -t commit -w --stdin)"
  git -C "$repo" update-ref refs/heads/feature/ABC-1-thing "$c"
  git -C "$repo" config filter.evil.clean "touch $canary/filter-clean; cat"
  git -C "$repo/sub" config filter.subevil.clean "touch $canary/submodule-filter; cat"
  printf '#!/bin/sh\ntouch %s/gpg-program\n' "$canary" > "$canary.gpg"; chmod 755 "$canary.gpg"
  git -C "$repo" config gpg.program "$canary.gpg"; git -C "$repo" config log.showSignature true
  git -C "$repo" config diff.external "touch $canary/diff-external"
  git -C "$repo" config core.pager "touch $canary/core-pager; cat"
  git -C "$repo" config pager.log "touch $canary/pager-log; cat"
  : > "$repo/.bearing/state/.session-s1"; touch -t 202001010000 "$repo/.bearing/state/.session-s1"
}
stir() { # make every tracked file stat-dirty, so git status must read its content
  touch -t 203001010000 "$repo/f.txt" "$repo/p.dat" "$repo/sub/s.txt"
}

t_begin "no hook runs a filter driver, a signature program or a submodule's filter"
gitrepo
stir; guard session --id s1 --source compact
stir; guard stop
stir; guard stop-gate --id s1
stir; guard precompact
stir; guard task-id "hi"
stir; guard format "$repo/f.txt"
stir; guard check-file "$repo/f.txt"
stir; hook session-start.sh '{"session_id":"s1","source":"compact"}'
stir; hook stop-summary.sh '{"session_id":"s1","stop_hook_active":false}'
stir; hook precompact.sh '{"session_id":"s1","trigger":"auto"}'
stir; hook session-end.sh '{"session_id":"s1"}'
stir; hook skill-start.sh '{"session_id":"s1","tool_input":{"skill":"x"}}'
stir; hook format-file.sh "{\"tool_input\":{\"file_path\":\"$repo/f.txt\"}}"
none_ran "a configured program ran from a hook's git"
t_end

t_begin "a long-running filter process never starts from a hook"
# A process filter that fails its handshake ends git status, so it has its own case.
gitrepo
git -C "$repo" config filter.evproc.process "touch $canary/filter-process"
stir; guard stop
stir; guard session --id s1 --source compact
stir; hook stop-summary.sh '{"session_id":"s1","stop_hook_active":false}'
stir; hook session-end.sh '{"session_id":"s1"}'
none_ran "a filter process ran from a hook's git"
t_end

t_begin "a filter whose name holds a quote or an equals sign is turned off too"
gitrepo
git -C "$repo" config --unset filter.evil.clean
printf "*.txt filter=a'b=c\n" > "$repo/.git/info/attributes"
git -C "$repo" config "filter.a'b=c.clean" "touch $canary/odd-name; cat"
stir; guard stop
stir; hook stop-summary.sh '{"session_id":"s1","stop_hook_active":false}'
none_ran "a filter with an odd name ran"
t_end

t_begin "under the hooks' git settings, no external diff, pager or filter runs"
gitrepo; echo b >> "$repo/f.txt"
# No hook runs a working-tree git diff; the submodule is the status case's.
git -C "$repo/sub" config --unset filter.subevil.clean
# lib.sh sets what every git a hook starts inherits; the guard holds the same function.
in_hook_env() { ( cd "$repo" && . "$HS/lib.sh" < /dev/null && eval "$1" ) >/dev/null 2>&1; }
in_hook_env "git diff"
in_hook_env "git log -p -1"
none_ran "git diff under the hook settings"
if script -qec true /dev/null >/dev/null 2>&1; then tty_run='script -qec "git log -1" /dev/null'
elif script -q /dev/null true >/dev/null 2>&1; then tty_run='script -q /dev/null git log -1'
else tty_run=''; fi
if [ -n "$tty_run" ]; then
  ( cd "$repo" && eval "$tty_run" ) >/dev/null 2>&1
  assert_eq 1 "$([ -n "$(find "$canary" -name 'pager-log' -o -name 'core-pager')" ] && echo 1)" "the pager fires on a terminal without the hook settings"
  rm -f "$canary"/*
  in_hook_env "$tty_run"
  none_ran "the pager under the hook settings"
else
  echo "hook_hardening: no script(1) here; the pager case is checked by the settings text only"
fi
lib_fn="$(sed -n '/^git_lockdown() {/,/^}/p' "$HS/lib.sh")"
guard_fn="$(sed -n '/^git_lockdown() {/,/^}/p' "$GUARD")"
assert_contains "$lib_fn" "GIT_PAGER=cat" "lib.sh sets GIT_PAGER"
assert_eq "$lib_fn" "$guard_fn" "the guard's git_lockdown is lib.sh's"
t_end

t_summary
