#!/usr/bin/env bash
# tests/unit/update_check.sh: brg-update-check and its place in brg-guard session.
# A local bare repo is the remote; HOME and XDG_CONFIG_HOME are temp dirs, so the
# network and the real ~/.claude are never touched.
set -u
. "$(dirname "$0")/../lib/assert.sh"
U="$KIT/plugins/bearing/bin/brg-update-check"
export HOME; HOME="$(tmpdir)"
unset BEARING_ENV BEARING_UPDATE_CHECK BEARING_UPDATE_SKIP BEARING_UPDATE_SNOOZE_UNTIL
remote="$(tmpdir)/r.git"; git init -q --bare "$remote"
w="$(tmpdir)"; git -C "$w" init -q -b main
git -C "$w" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m a
for t in v0.7.0 v0.8.0 v0.9.0 v0.10.0 v0.11.0-rc1 v0.12.0-beta; do git -C "$w" tag "$t"; done
git -C "$w" push -q "$remote" --tags
git -C "$w" push -q "$remote" main 2>/dev/null
cfg="$(tmpdir)"
fresh() { rm -f "$cfg/bearing/update-check"; }
run() { XDG_CONFIG_HOME="$cfg" bash "$U" --remote "$remote" --installed "$1" "${@:2}"; }

t_begin "newest numeric, not lexical; pre-releases ignored"
fresh
assert_exit 0 run 0.9.0
assert_contains "$T_OUT" "BEARING_UPDATE: 0.9.0 -> 0.10.0"
assert_not_contains "$T_OUT" "rc1" "pre-release not offered"
assert_not_contains "$T_OUT" "0.12.0" "pre-release not offered"
assert_contains "$T_OUT" "See CHANGELOG.md at $remote" "no local section for 0.10.0"
assert_file "$cfg/bearing/update-check"
assert_contains "$(cat "$cfg/bearing/update-check")" "v0.10.0" "cache holds the newest"
t_end

t_begin "up to date, and ahead of the newest tag"
fresh
assert_exit 0 run 0.10.0
assert_eq "" "$T_OUT"
fresh
assert_exit 0 run 0.11.0
assert_eq "" "$T_OUT" "0.11.0 is above the newest release"
t_end

t_begin "a fresh cache is used without asking the remote"
printf '%s\tv9.0.0\n' "$(date +%s)" > "$cfg/bearing/update-check"
assert_exit 0 run 0.7.0 --remote "/nonexistent/x.git"
assert_contains "$T_OUT" "BEARING_UPDATE: 0.7.0 -> 9.0.0"
printf '%s\tv9.0.0\n' "$(( $(date +%s) - 90000 ))" > "$cfg/bearing/update-check"
assert_exit 0 run 0.7.0
assert_contains "$T_OUT" "-> 0.10.0" "a stale cache is refreshed"
t_end

t_begin "offline prints nothing within budget"
fresh; s=$(date +%s)
assert_exit 0 run 0.7.0 --remote "/nonexistent/x.git" --budget 3
assert_eq "" "$T_OUT"
assert_eq 1 "$([ $(( $(date +%s) - s )) -le 4 ] && echo 1 || echo 0)" "within budget"
assert_contains "$(cat "$cfg/bearing/update-check")" "	-	ls-remote-failed" "only a negative entry on failure"
t_end

# A remote that hangs: a local git:// listener that counts each connection
# and never answers. brg-update-check runs git from /usr/bin:/bin under a
# cleared environment, so a git stub on PATH would never be reached.
hang_srv() { # hang_srv <calls file> <port file>: start the listener (SRV_PID) and wait for its port
  local pf="$2"
  python3 -I -c '
import socket, sys, time
s = socket.socket(); s.bind(("127.0.0.1", 0)); s.listen(8)
open(sys.argv[2], "w").write(str(s.getsockname()[1]))
held = []
end = time.time() + 120
s.settimeout(1)
while time.time() < end:
    try:
        c, _ = s.accept()
    except socket.timeout:
        continue
    open(sys.argv[1], "a").write("x\n")
    held.append(c)
' "$1" "$pf" </dev/null >/dev/null 2>&1 &
  SRV_PID=$!
  while [ ! -s "$pf" ]; do sleep 0.1; done
}
calls="$(tmpdir)/calls"; : > "$calls"; portf="$(tmpdir)/port"
hang_srv "$calls" "$portf"; port="$(cat "$portf")"
hang="git://127.0.0.1:$port/r.git"

t_begin "a remote that hangs: killed inside the budget, cache untouched, logged"
repo="$(tmpdir)"; git -C "$repo" init -q; mkdir -p "$repo/.bearing"
fresh; s=$(date +%s)
T_OUT="$(cd "$repo" && XDG_CONFIG_HOME="$cfg" bash "$U" --remote "$hang" --installed 0.7.0 --budget 2 2>&1)"; T_RC=$?
el=$(( $(date +%s) - s ))
assert_eq 0 "$T_RC" "exit 0"
assert_eq "" "$T_OUT"
assert_eq 1 "$([ "$el" -le 4 ] && echo 1 || echo 0)" "returned in ${el}s"
assert_contains "$(cat "$cfg/bearing/update-check")" "	-	timeout" "only a negative entry, no tag"
assert_eq 0 "$(ls "$cfg/bearing" 2>/dev/null | grep -c 'update-check\.')" "no cache temp file left"
assert_contains "$(cat "$repo/.bearing/state/gates.log")" "update-check	not-run	0	timeout" "logged"
assert_eq 1 "$(wc -l < "$calls" | tr -d ' ')" "the listener was reached once"
t_end

t_begin "a source checkout shows the changelog section, at most 8 lines"
printf '%s\tv0.7.0\n' "$(date +%s)" > "$cfg/bearing/update-check"
assert_exit 0 run 0.6.0
assert_contains "$T_OUT" "BEARING_UPDATE: 0.6.0 -> 0.7.0"
assert_contains "$T_OUT" "First public release" "section from CHANGELOG.md"
nl="$(printf '%s\n' "$T_OUT" | wc -l | tr -d ' ')"
assert_eq 1 "$([ "$nl" -le 9 ] && echo 1 || echo 0)" "header plus 8 lines (got $nl; last two: $(printf '%s\n' "$T_OUT" | tail -2 | tr '\n' '|'))"
t_end

t_begin "a failed check is remembered: no second ls-remote for 6 hours"
fresh; : > "$calls"
XDG_CONFIG_HOME="$cfg" bash "$U" --remote "$hang" --installed 0.7.0 --budget 1 >/dev/null 2>&1
assert_contains "$(cat "$cfg/bearing/update-check")" "	-	timeout" "negative entry"
s=$(date +%s%N 2>/dev/null || echo 0)
T_OUT="$(XDG_CONFIG_HOME="$cfg" bash "$U" --remote "$hang" --installed 0.7.0 --budget 3 2>&1)"
e=$(date +%s%N 2>/dev/null || echo 0)
assert_eq "" "$T_OUT"
assert_eq 1 "$(wc -l < "$calls" | tr -d ' ')" "ls-remote called once only"
case "$s" in *N|0) ;; *) assert_eq 1 "$([ $(( (e - s) / 1000000 )) -lt 500 ] && echo 1 || echo 0)" "second run under 0.5 s";; esac
printf '%s\t-\ttimeout\n' "$(( $(date +%s) - 22000 ))" > "$cfg/bearing/update-check"
assert_exit 0 run 0.7.0
assert_contains "$T_OUT" "-> 0.10.0" "after 6 hours it tries again"
kill "$SRV_PID" 2>/dev/null; wait "$SRV_PID" 2>/dev/null
t_end

t_begin "a hostile remote is never run as a command or option"
fresh; pwn="$(tmpdir)/pwned"
assert_exit 0 run 0.7.0 --remote "--upload-pack=touch $pwn"
assert_eq "" "$T_OUT"
assert_eq 0 "$([ -e "$pwn" ] && echo 1 || echo 0)" "--upload-pack not run"
assert_eq 0 "$([ -e "$cfg/bearing/update-check" ] && echo 1 || echo 0)" "refused before any lookup"
assert_exit 0 run 0.7.0 --remote "ext::sh -c touch $pwn"
assert_eq 0 "$([ -e "$pwn" ] && echo 1 || echo 0)" "ext:: not run"
t_end

t_begin "skipped version"
fresh; mkdir -p "$cfg/bearing"; echo 'BEARING_UPDATE_SKIP=0.10.0' > "$cfg/bearing/bearing.env"
assert_exit 0 run 0.7.0
assert_eq "" "$T_OUT"
echo 'BEARING_UPDATE_SKIP=0.9.0' > "$cfg/bearing/bearing.env"
assert_exit 0 run 0.7.0
assert_contains "$T_OUT" "-> 0.10.0" "skipping another version does not hide this one"
t_end

t_begin "skip written by brg-config (double-quoted form)"
XDG_CONFIG_HOME="$cfg" bash "$KIT/plugins/bearing/bin/brg-config" set update-skip "0.10.0" --user
assert_exit 0 run 0.7.0
assert_eq "" "$T_OUT"
t_end

t_begin "snoozed"
echo "BEARING_UPDATE_SNOOZE_UNTIL=$(( $(date +%s) + 999 ))" > "$cfg/bearing/bearing.env"
assert_exit 0 run 0.7.0
assert_eq "" "$T_OUT"
echo "BEARING_UPDATE_SNOOZE_UNTIL=$(( $(date +%s) - 5 ))" > "$cfg/bearing/bearing.env"
assert_exit 0 run 0.7.0
assert_contains "$T_OUT" "-> 0.10.0" "an elapsed snooze offers again"
t_end

t_begin "off"
: > "$cfg/bearing/bearing.env"
fresh
assert_exit 0 env BEARING_UPDATE_CHECK=off XDG_CONFIG_HOME="$cfg" bash "$U" --remote "$remote" --installed 0.7.0
assert_eq "" "$T_OUT"
echo 'BEARING_UPDATE_CHECK=off' > "$cfg/bearing/bearing.env"
assert_exit 0 run 0.7.0
assert_eq "" "$T_OUT" "off from bearing.env"
assert_eq 0 "$([ -e "$cfg/bearing/update-check" ] && echo 1 || echo 0)" "off does not even look"
: > "$cfg/bearing/bearing.env"
t_end

t_begin "brg-guard session: startup only, prompt line, existing lines kept"
gr="$(tmpdir)"; git -C "$gr" init -q -b main
fresh
sess() { (cd "$gr" && XDG_CONFIG_HOME="$cfg" bash "$GUARD" session --id S1 --source "$1"); }
# the guard finds the check beside itself and reads the remote from known_marketplaces.json
mkdir -p "$HOME/.claude/plugins"
printf '{"bearing":{"source":{"source":"git","url":"%s"}}}\n' "$remote" > "$HOME/.claude/plugins/known_marketplaces.json"
pj="$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$KIT/plugins/bearing/.claude-plugin/plugin.json" | head -1)"
if [ "$(printf '%s\n%s\n' "$pj" 0.10.0 | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)" = "0.10.0" ] && [ "$pj" != "0.10.0" ]; then
  assert_exit 0 sess startup
  assert_contains "$T_OUT" "bearing session: branch=main" "existing line"
  assert_contains "$T_OUT" "BEARING_UPDATE: $pj -> 0.10.0"
  assert_contains "$T_OUT" "Bearing 0.10.0 is available (you have $pj). Ask the user with AskUserQuestion: Upgrade now (run the upgrade-tools skill) / Remind me tomorrow (brg-config set update-snooze-until "
  assert_contains "$T_OUT" "--user) / Skip this version (brg-config set update-skip 0.10.0 --user)."
  for src in resume compact clear; do
    assert_exit 0 sess "$src"
    assert_not_contains "$T_OUT" "BEARING_UPDATE" "no check on $src"
  done
else
  assert_eq 1 1 "plugin version $pj is not below the fixture's 0.10.0; session offer not exercised"
fi
t_end
t_summary
