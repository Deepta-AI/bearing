#!/usr/bin/env bash
# tests/unit/stop_hint.sh: the first edit of a session tells Claude, once and
# as additionalContext, what the Stop gate will ask, so the report is written
# after the check instead of twice; later edits print the check-file line as
# before. And every hook but the Bash guard answers for the event's cwd, not
# the directory the harness started it in (the desktop app starts a worktree
# session's hooks in the main checkout). bash 3.2 safe.
set -u
. "$(dirname "$0")/../lib/assert.sh"
HS="$KIT/plugins/bearing/hooks/scripts"

newrepo() { # repo: a Bearing repository on feature/ABC-1-thing whose make check writes the marker
  repo="$(tmpdir)"
  git -C "$repo" init -q -b main
  git -C "$repo" config user.email t@example.com; git -C "$repo" config user.name t
  printf '.bearing/state/\n' > "$repo/.gitignore"
  printf 'check:\n\t@touch .bearing/state/.check-passed\n' > "$repo/Makefile"
  printf 'a\n' > "$repo/f.txt"
  git -C "$repo" add .gitignore Makefile f.txt; git -C "$repo" commit -q -m "chore: init"
  git -C "$repo" switch -q -c feature/ABC-1-thing
  mkdir -p "$repo/.bearing/state"
}
edit() { # edit <session id>: the edit hook for f.txt, run from the repository
  T_IN="{\"session_id\":\"$1\",\"tool_input\":{\"file_path\":\"$repo/f.txt\"}}"
  assert_exit 0 bash -c "cd '$repo' && bash '$HS/format-file.sh' 2>/dev/null"
}

t_begin "the first edit of a held session hands Claude the hint and the check-file line"
newrepo; : > "$repo/.bearing/state/.session-s1"
edit s1
ctx="$(printf '%s' "$T_OUT" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null)"
assert_eq PostToolUse "$(printf '%s' "$T_OUT" | jq -r '.hookSpecificOutput.hookEventName' 2>/dev/null)" "one JSON object for PostToolUse"
assert_contains "$ctx" "the Stop gate holds it to make check" "names the target"
assert_contains "$ctx" "before your final report" "says when"
assert_contains "$ctx" "check-file: not run by the hook" "keeps the check-file line"
assert_file "$repo/.bearing/state/.session-s1.hinted"
t_end

t_begin "later edits print the plain check-file line only"
edit s1
assert_contains "$T_OUT" "check-file: not run by the hook"
assert_not_contains "$T_OUT" "hookSpecificOutput" "the hint is given once"
t_end

t_begin "the hint names check-changed when the Makefile has it"
newrepo; : > "$repo/.bearing/state/.session-s2"
printf 'check-changed:\n\t@true\n' >> "$repo/Makefile"
edit s2
assert_contains "$T_OUT" "holds it to make check-changed"
t_end

t_begin "no hint where the Stop gate would not hold the session"
newrepo
edit s3
assert_not_contains "$T_OUT" "hookSpecificOutput" "no session mark"
: > "$repo/.bearing/state/.session-s4"; printf 'check:\n\t@true\n' > "$repo/Makefile"
edit s4
assert_not_contains "$T_OUT" "hookSpecificOutput" "a Makefile that never writes the marker"
edit '../x'
assert_not_contains "$T_OUT" "hookSpecificOutput" "an id that is not a plain name"
t_end

t_begin "an edit the gate does not count gives no hint and keeps it for one that does"
newrepo; : > "$repo/.bearing/state/.session-s7"
printf 'ignored.txt\n' >> "$repo/.gitignore"; printf 'i\n' > "$repo/ignored.txt"
out="$(tmpdir)"; printf 'o\n' > "$out/o.txt"
for f in "$repo/ignored.txt" "$out/o.txt" "$repo/.bearing/state/note.md"; do
  : > "$repo/.bearing/state/note.md"
  T_IN="{\"session_id\":\"s7\",\"tool_input\":{\"file_path\":\"$f\"}}"
  assert_exit 0 bash -c "cd '$repo' && bash '$HS/format-file.sh' 2>/dev/null"
  assert_not_contains "$T_OUT" "hookSpecificOutput" "no hint for ${f##*/}"
done
nomark=0; [ -e "$repo/.bearing/state/.session-s7.hinted" ] && nomark=1
assert_eq 0 "$nomark" "no mark written"
edit s7
assert_contains "$T_OUT" "hookSpecificOutput" "the first counted edit hears it"
t_end

t_begin "a Makefile that is a FIFO does not hang the hint or the gate"
newrepo; : > "$repo/.bearing/state/.session-s8"; rm -f "$repo/Makefile"; mkfifo "$repo/Makefile"
T_IN="{\"session_id\":\"s8\",\"tool_input\":{\"file_path\":\"$repo/f.txt\"}}"
( cd "$repo" && printf '%s' "$T_IN" | bash "$HS/format-file.sh" >/dev/null 2>&1 ) & p=$!
i=0; while kill -0 "$p" 2>/dev/null && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i+1)); done
ended=1; kill -0 "$p" 2>/dev/null && { ended=0; kill "$p" 2>/dev/null; }; wait "$p" 2>/dev/null
assert_eq 1 "$ended" "the edit hook ends within 5 s"
( cd "$repo" && bash "$GUARD" stop-gate --id s8 ) </dev/null >/dev/null 2>&1 & p=$!
i=0; while kill -0 "$p" 2>/dev/null && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i+1)); done
ended=1; kill -0 "$p" 2>/dev/null && { ended=0; kill "$p" 2>/dev/null; }; wait "$p" 2>/dev/null
assert_eq 1 "$ended" "stop-gate ends within 5 s"
rm -f "$repo/Makefile"
t_end

t_begin "a cd into a nested repository does not move the Stop gate"
newrepo; : > "$repo/.bearing/state/.session-s9"; touch -t 202001010000 "$repo/.bearing/state/.session-s9"
touch -t 202001010000 "$repo/.bearing/state/.check-passed"
mkdir -p "$repo/vendor/sub"; git -C "$repo/vendor/sub" init -q -b main
printf 'x\n' > "$repo/fresh.txt"
T_IN="{\"session_id\":\"s9\",\"stop_hook_active\":false,\"cwd\":\"$repo/vendor/sub\"}"
assert_exit 0 bash -c "cd '$repo/vendor/sub' && bash '$HS/stop-summary.sh' 2>/dev/null"
assert_contains "$T_OUT" '"decision"' "the session's repository is still held"
assert_contains "$T_OUT" "Run make check" "with its target"
t_end

t_begin "hooks answer for the event's cwd, not the directory they started in"
newrepo
elsewhere="$(tmpdir)"; git -C "$elsewhere" init -q -b main
T_IN="{\"session_id\":\"s5\",\"source\":\"startup\",\"cwd\":\"$repo\"}"
assert_exit 0 bash -c "cd '$elsewhere' && bash '$HS/session-start.sh' 2>/dev/null"
assert_contains "$T_OUT" "branch=feature/ABC-1-thing" "the session's branch, not the start directory's"
assert_file "$repo/.bearing/state/.session-s5"
T_IN="{\"session_id\":\"s6\",\"source\":\"startup\",\"cwd\":\"/no/such/dir\"}"
assert_exit 0 bash -c "cd '$repo' && bash '$HS/session-start.sh' 2>/dev/null"
assert_contains "$T_OUT" "branch=feature/ABC-1-thing" "a missing cwd keeps the start directory"
t_end

t_summary
