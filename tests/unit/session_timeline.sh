#!/usr/bin/env bash
# tests/unit/session_timeline.sh: timeline start, implicit end, close, recent,
# no-op outside a Bearing repo, and a branch without a task id.
set -u
. "$(dirname "$0")/../lib/assert.sh"
S="$KIT/plugins/bearing/bin/brg-session"
repo="$(tmpdir)"; git -C "$repo" init -q -b feat/RuntimeAndFeel; mkdir -p "$repo/.bearing/state"
in_repo() { ( cd "$repo" && bash "$S" "$@" ) }
tl="$repo/.bearing/state/timeline.jsonl"

t_begin "start, implicit end, close"
assert_exit 0 in_repo timeline-start --id s1 --skill bearing:start-task
assert_exit 0 in_repo timeline-start --id s1 --skill bearing:test-cases
assert_exit 0 in_repo timeline-close --id s1
assert_eq 4 "$(wc -l < "$tl" | tr -d ' ')" "four events"
assert_contains "$(sed -n 2p "$tl")" '"skill":"bearing:start-task","event":"end"'
assert_contains "$(sed -n 4p "$tl")" '"skill":"bearing:test-cases","event":"end"'
assert_contains "$(sed -n 1p "$tl")" '"epoch":'
t_end

t_begin "recent lists ended skills on the branch, newest last"
assert_exit 0 in_repo timeline-recent --n 3
assert_eq "bearing:start-task
bearing:test-cases" "$T_OUT"
t_end

t_begin "no .bearing directory is a silent no-op"
other="$(tmpdir)"; git -C "$other" init -q -b main
assert_exit 0 bash -c "cd '$other' && bash '$S' timeline-start --id s1 --skill x"
assert_eq "" "$T_OUT"
assert_eq 1 "$([ ! -e "$other/.bearing" ] && echo 1)" "nothing created"
t_end

t_begin "hostile skill names keep every line valid JSON"
: > "$tl"
assert_exit 0 in_repo timeline-start --id s2 --skill "$(printf 'nl\nx')"
assert_exit 0 in_repo timeline-start --id s2 --skill 'q"b\s'
assert_exit 0 in_repo timeline-close --id s2
assert_eq 4 "$(wc -l < "$tl" | tr -d ' ')" "one line per event"
bad=0; while IFS= read -r l; do printf '%s' "$l" | jq -e . >/dev/null 2>&1 || bad=$((bad+1)); done < "$tl"
assert_eq 0 "$bad" "unparseable lines"
assert_eq 'q"b\s' "$(jq -r 'select(.event=="end") | .skill' "$tl" | tail -1)" "quote and backslash round trip"
t_end

t_begin "branch is matched literally, not as a regex"
: > "$tl"
git -C "$repo" checkout -q -b 'feat/a.b+c'
assert_exit 0 in_repo timeline-start --id s3 --skill one
assert_exit 0 in_repo timeline-close --id s3
git -C "$repo" checkout -q -b 'feat/aXb+c'
assert_exit 0 in_repo timeline-start --id s4 --skill two
assert_exit 0 in_repo timeline-close --id s4
assert_exit 0 in_repo timeline-recent --branch 'feat/a.b+c'
assert_eq one "$T_OUT"
assert_exit 0 in_repo timeline-recent --branch 'feat/[x'
assert_eq "" "$T_OUT"
t_end

t_begin "a branch without a task id still records"
git -C "$repo" checkout -q -b scratch
assert_exit 0 in_repo timeline-start --id s5 --skill bearing:workflow
assert_contains "$(tail -1 "$tl")" '"branch":"scratch"'
t_end

t_begin "not-run logs a gates.log line"
assert_exit 0 in_repo not-run --skill unparsed
assert_contains "$(tail -1 "$repo/.bearing/state/gates.log")" "timeline	not-run	0	unparsed"
t_end

t_begin "hook without jq exits 0 silently and logs timeline not-run"
nojq="$(tmpdir)"
for c in bash dirname git date tr cut sed grep cat wc tail mkdir python3; do ln -s "$(command -v $c)" "$nojq/$c"; done
HK="$KIT/plugins/bearing/hooks/scripts/skill-start.sh"
: > "$repo/.bearing/state/gates.log"
T_IN='{"session_id":"z","tool_input":{"skill":"bearing:workflow"}}'
out="$(cd "$repo" && echo "$T_IN" | PATH="$nojq" "$nojq/bash" "$HK" 2>/dev/null; echo "rc=$?")"
assert_eq "rc=0" "$out" "no stdout, exit 0"
assert_contains "$(tail -1 "$repo/.bearing/state/gates.log")" "timeline	not-run	0	unparsed"
t_end

t_summary
