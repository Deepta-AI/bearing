#!/usr/bin/env bash
# tests/unit/guard_harness_gates.sh: the three harness gates. check-file lints
# one edited file (stub linters on a fake PATH, the Makefile override, a tool
# that cannot run); stop-gate holds a session to the files it changed since
# make check last passed, once, and never loops; precompact writes a snapshot
# that session --source compact reads back. Then the Claude Code adapters turn
# a gate's exit 2 into {"decision": "block"}.
set -u
. "$(dirname "$0")/../lib/assert.sh"

repo="$(tmpdir)"
git -C "$repo" init -q -b main
printf '.bearing/state/\n' > "$repo/.gitignore"
mkdir -p "$repo/.bearing"
printf 'check:\n\t@touch .bearing/state/.check-passed\n' > "$repo/Makefile"
git -C "$repo" add .gitignore Makefile
git -C "$repo" -c user.email=t@example.com -c user.name=t commit -q -m "init"
in_repo() { ( cd "$repo" && bash "$GUARD" "$@" ) }
state="$repo/.bearing/state"

stubs="$(tmpdir)"
# ruff fails on any file named bad.py; shellcheck passes; eslint reports a
# missing configuration, which is the tool failing, not the file.
printf '#!/usr/bin/env bash\ncase "$*" in *bad.py*) echo "bad.py:1:1: F401 os imported but unused"; exit 1;; esac\n' > "$stubs/ruff"
printf '#!/usr/bin/env bash\nexit 0\n' > "$stubs/shellcheck"
chmod 755 "$stubs/ruff" "$stubs/shellcheck"
base="$(minimal_path bash git sed grep head tail tr wc cat dirname basename mktemp rm mkdir ls awk env printf jq make find date mv touch)"
check_with() { ( cd "$repo" && PATH="$stubs:$base" bash "$GUARD" check-file "$1" ) }

t_begin "check-file sends problems back and passes clean files"
printf 'import os\n' > "$repo/bad.py"; printf 'x = 1\n' > "$repo/good.py"; printf 'echo hi\n' > "$repo/ok.sh"
assert_exit 2 check_with "$repo/bad.py"
assert_contains "$T_OUT" "bearing check: ruff found problems in bad.py"
assert_contains "$T_OUT" "F401 os imported but unused"
assert_exit 0 check_with "$repo/good.py"
assert_eq "" "$T_OUT" "clean file is silent"
assert_exit 0 check_with "$repo/ok.sh"
assert_eq "" "$T_OUT"
t_end

t_begin "check-file on JSON, JSONC and unknown files"
printf '{"a": 1,}\n' > "$repo/data.json"; printf '{"a": 1}\n' > "$repo/fine.json"
printf '{ // comment\n}\n' > "$repo/tsconfig.json"; printf 'hello\n' > "$repo/notes.txt"
assert_exit 2 check_with "$repo/data.json"
assert_contains "$T_OUT" "jq found problems in data.json"
assert_exit 0 check_with "$repo/fine.json"
assert_exit 0 check_with "$repo/tsconfig.json"
assert_eq "" "$T_OUT" "tsconfig allows comments; not checked"
assert_exit 0 check_with "$repo/notes.txt"
assert_eq "" "$T_OUT"
t_end

t_begin "check-file does nothing without a file or a linter"
assert_exit 0 check_with ""
assert_exit 0 check_with "__BRG_UNPARSED__"
assert_exit 0 check_with "$repo/missing.py"
printf 'package main\n' > "$repo/main.go"
assert_exit 0 check_with "$repo/main.go"
assert_eq "" "$T_OUT" "no go on PATH: silent"
t_end

t_begin "check-file says a tool that cannot run did not check the file"
mkdir -p "$repo/node_modules/.bin"
printf '#!/usr/bin/env bash\necho "ESLint couldn'"'"'t find a configuration file."; exit 2\n' > "$repo/node_modules/.bin/eslint"
chmod 755 "$repo/node_modules/.bin/eslint"
printf 'let a = 1\n' > "$repo/app.ts"
assert_exit 0 check_with "$repo/app.ts"
assert_contains "$T_OUT" "eslint could not check app.ts here"
rm -rf "$repo/node_modules"
t_end

t_begin "check-file prefers the repository's make check-file"
printf 'check:\n\t@touch .bearing/state/.check-passed\ncheck-file:\n\t@echo "custom saw $(FILE)"; exit 1\n' > "$repo/Makefile"
assert_exit 2 check_with "$repo/good.py"
assert_contains "$T_OUT" "make check-file found problems in good.py"
assert_contains "$T_OUT" "custom saw good.py"
git -C "$repo" checkout -q Makefile
t_end

rm -f "$repo"/bad.py "$repo"/good.py "$repo"/ok.sh "$repo"/data.json "$repo"/fine.json "$repo"/tsconfig.json "$repo"/notes.txt "$repo"/main.go "$repo"/app.ts

t_begin "session --id marks the session start once"
assert_exit 0 in_repo session --id S1 --source startup
assert_file "$state/.session-S1"
printf 'first\n' > "$state/.session-S1"
assert_exit 0 in_repo session --id S1 --source resume
assert_eq "first" "$(cat "$state/.session-S1")" "resume keeps the first mark"
touch -t 202001010000 "$state/.session-S1"
t_end

t_begin "stop-gate holds a session to its unchecked changes, once"
printf 'a\n' > "$repo/work.txt"
assert_exit 2 in_repo stop-gate --id S1
assert_contains "$T_OUT" "1 file(s) changed in this session since make check last passed"
assert_contains "$T_OUT" "Run make check"
assert_exit 0 in_repo stop-gate --id S1 --active
assert_contains "$T_OUT" "Not checked; say so under Not done"
t_end

t_begin "stop-gate lets a session stop after make check passes"
( cd "$repo" && make -s check )
assert_exit 0 in_repo stop-gate --id S1
assert_eq "" "$T_OUT"
printf 'b\n' > "$repo/work.txt"; touch -t 203001010000 "$repo/work.txt"
assert_exit 2 in_repo stop-gate --id S1
assert_contains "$T_OUT" "1 file(s) changed"
t_end

t_begin "stop-gate ignores changes made before the session began"
: > "$state/.session-S2"; touch -t 203501010000 "$state/.session-S2"
assert_exit 0 in_repo stop-gate --id S2
assert_eq "" "$T_OUT"
t_end

t_begin "stop-gate only reminds without a session mark or a marker-writing Makefile"
assert_exit 0 in_repo stop-gate --id NOPE
assert_contains "$T_OUT" "make check has not passed since"
assert_exit 0 in_repo stop-gate --id "__BRG_UNPARSED__"
printf 'check:\n\t@true\n' > "$repo/Makefile"
assert_exit 0 in_repo stop-gate --id S1
assert_contains "$T_OUT" "make check has not passed since"
git -C "$repo" checkout -q Makefile
t_end

t_begin "precompact writes a snapshot that session reads back after compaction"
git -C "$repo" checkout -q -b feature/TASK-9-gates
transcript="$repo/.bearing/state/t.jsonl"
{
  printf '%s\n' '{"type":"user","message":{"role":"user","content":"first ask: build the gate"}}'
  printf '%s\n' '{"type":"user","isMeta":true,"message":{"role":"user","content":"meta line"}}'
  printf '%s\n' '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","content":"tool output"}]}}'
  printf '%s\n' '{"type":"user","message":{"role":"user","content":"<task-notification>done</task-notification>"}}'
  printf '%s\n' '{"type":"assistant","message":{"role":"assistant","content":"sure"}}'
  printf '%s\n' '{"type":"user","message":{"role":"user","content":"second ask:\nkeep it small"}}'
} > "$transcript"
assert_exit 0 in_repo precompact "$transcript"
assert_contains "$T_OUT" "compaction snapshot written to .bearing/state/feature_TASK-9-gates.compact.md"
snap="$(cat "$state/feature_TASK-9-gates.compact.md")"
assert_contains "$snap" "Branch: feature/TASK-9-gates   Task: TASK-9"
assert_contains "$snap" "work.txt"
assert_contains "$snap" "not passed since 1 file(s) last changed"
assert_contains "$snap" "- first ask: build the gate"
assert_contains "$snap" "- second ask:"
assert_not_contains "$snap" "meta line"
assert_not_contains "$snap" "tool output"
assert_not_contains "$snap" "task-notification"
assert_exit 0 in_repo session --id S1 --source compact
assert_contains "$T_OUT" "The context was just summarised"
assert_contains "$T_OUT" "first ask: build the gate"
assert_exit 0 in_repo session --id S1 --source startup
assert_not_contains "$T_OUT" "just summarised" "startup does not replay the snapshot"
t_end

t_begin "precompact without .bearing or a transcript"
plain="$(tmpdir)"; git -C "$plain" init -q
assert_exit 0 bash -c "cd '$plain' && bash '$GUARD' precompact ''"
assert_eq "" "$T_OUT" "not a Bearing repository: nothing written"
assert_exit 0 in_repo precompact "__BRG_UNPARSED__"
assert_not_contains "$(cat "$state/feature_TASK-9-gates.compact.md")" "last requests" "no transcript: no requests section"
t_end

t_begin "telemetry: gate decisions are logged here, summarised by stats, never elsewhere"
tl="$(tmpdir)"; git -C "$tl" init -q; mkdir -p "$tl/.bearing"
at_tl() { ( cd "$tl" && bash "$GUARD" "$@" ) }
assert_exit 1 at_tl stats
assert_contains "$T_OUT" "0 gate decisions logged"
assert_exit 0 at_tl command "ls -la"
assert_exit 2 at_tl command "git pu$(printf sh) origin main"
printf '{"a": 1,}\n' > "$tl/bad.json"
( cd "$tl" && PATH="$stubs:$base" bash "$GUARD" check-file bad.json >/dev/null 2>&1 )
assert_exit 0 at_tl stats
assert_contains "$T_OUT" "3 gate decisions"
assert_contains "$T_OUT" "command allowed"
assert_contains "$T_OUT" "command refused"
assert_contains "$T_OUT" "check-file problems"
assert_contains "$T_OUT" "most refused:"
log="$(cat "$tl/.bearing/state/gates.log")"
assert_not_contains "$log" "origin main" "the command text is never logged"
( cd "$tl" && BEARING_NO_GATE_LOG=1 bash "$GUARD" command "ls" )
assert_eq 3 "$(wc -l < "$tl/.bearing/state/gates.log" | tr -d ' ')" "BEARING_NO_GATE_LOG=1 logs nothing"
plain2="$(tmpdir)"; git -C "$plain2" init -q
( cd "$plain2" && bash "$GUARD" command "ls" )
assert_eq 0 "$(find "$plain2" -name gates.log | wc -l | tr -d ' ')" "no log outside a Bearing repository"
t_end

t_begin "telemetry: the stop gate records blocked, reminded and passed"
st_repo_log="$state/gates.log"
: > "$st_repo_log"
printf 'z\n' > "$repo/z.txt"; touch -t 203001010000 "$repo/z.txt"
assert_exit 2 in_repo stop-gate --id S1
assert_exit 0 in_repo stop-gate --id S1 --active
assert_contains "$(cat "$st_repo_log")" "stop-gate	blocked"
assert_contains "$(cat "$st_repo_log")" "stop-gate	reminded"
rm -f "$repo/z.txt"
t_end

HS="$KIT/plugins/bearing/hooks/scripts"
t_begin "Claude adapters: a gate's exit 2 becomes decision block"
T_IN='{"session_id":"S1","stop_hook_active":false}'
assert_exit 0 bash -c "cd '$repo' && bash '$HS/stop-summary.sh'"
assert_eq "block" "$(printf '%s' "$T_OUT" | jq -r .decision)" "stop blocks once"
assert_contains "$(printf '%s' "$T_OUT" | jq -r .reason)" "since make check last passed"
T_IN='{"session_id":"S1","stop_hook_active":true}'
assert_exit 0 bash -c "cd '$repo' && bash '$HS/stop-summary.sh'"
assert_contains "$T_OUT" "Not checked"
assert_not_contains "$T_OUT" '"decision"' "second stop never blocks"
printf '{"a": 1,}\n' > "$repo/broken.json"
T_IN="{\"tool_input\":{\"file_path\":\"$repo/broken.json\"}}"
assert_exit 0 bash -c "cd '$repo' && bash '$HS/format-file.sh' 2>/dev/null"
assert_eq "block" "$(printf '%s' "$T_OUT" | jq -r .decision)" "stdout is the JSON and nothing else"
assert_contains "$T_OUT" "jq found problems in broken.json"
T_IN="{\"session_id\":\"S1\",\"transcript_path\":\"$transcript\",\"trigger\":\"auto\"}"
assert_exit 0 bash -c "cd '$repo' && bash '$HS/precompact.sh'"
assert_contains "$T_OUT" "compaction snapshot written"
T_IN=''
t_end

t_summary
