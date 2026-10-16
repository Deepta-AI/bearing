#!/usr/bin/env bash
# tests/unit/learn_local.sh: consent states; nothing written unless on;
# counts increment; paths reduced or dropped; top ranks by count; the guard
# session ask and read back; gate blocks and reruns feed the log.
set -u
. "$(dirname "$0")/../lib/assert.sh"
L="$KIT/plugins/bearing/bin/brg-learn"
cfg="$(tmpdir)"; f="$cfg/bearing/learnings.jsonl"
run() { XDG_CONFIG_HOME="$cfg" bash "$L" "$@"; }
t_begin "unanswered is ask and writes nothing"
assert_exit 0 run state
assert_eq ask "$T_OUT"
assert_exit 0 run log --kind gate-block --skill go --key vet --insight "vet fails in src/a/b.go"
nofile=0; [ -e "$f" ] && nofile=1; assert_eq 0 "$nofile" "no file"
t_end
t_begin "off writes nothing"
mkdir -p "$cfg/bearing"; echo BEARING_LEARNING=off > "$cfg/bearing/bearing.env"
assert_exit 0 run state
assert_eq off "$T_OUT"
assert_exit 0 run log --kind manual --skill go --key x --insight y
nofile=0; [ -e "$f" ] && nofile=1; assert_eq 0 "$nofile" "no file"
t_end
t_begin "a quoted value counts as on"
echo 'BEARING_LEARNING="on"' > "$cfg/bearing/bearing.env"
assert_exit 0 run state
assert_eq on "$T_OUT"
t_end
t_begin "on logs, increments and reduces paths"
echo BEARING_LEARNING=on > "$cfg/bearing/bearing.env"
run log --kind gate-block --skill go --key vet --insight "vet fails in src/a/b.go" >/dev/null
run log --kind gate-block --skill go --key vet --insight "vet fails in src/a/b.go" >/dev/null
run log --kind manual --skill go --key other --insight "prefer table tests" >/dev/null
assert_eq 2 "$(wc -l < "$f" | tr -d ' ')" "two distinct entries"
assert_contains "$(cat "$f")" '"count":2'
assert_contains "$(cat "$f")" '*.go'
assert_not_contains "$(cat "$f")" 'src/a/b.go'
assert_not_contains "$(cat "$f")" 'repo'
t_end
t_begin "top ranks by count"
assert_exit 0 run top --skills "go" --n 1
assert_eq "- vet fails in *.go (2x)" "$T_OUT"
assert_exit 0 run top --skills "python" --n 5
assert_eq "" "$T_OUT"
t_end
t_begin "absolute and extensionless paths are reduced"
g="$(tmpdir)"; export XDG_CONFIG_HOME="$g"; mkdir -p "$g/bearing"; echo BEARING_LEARNING=on > "$g/bearing/bearing.env"
bash "$L" log --kind manual --skill go --key a --insight "edit /home/u/x.go and src/dir/Makefile then"
out="$(cat "$g/bearing/learnings.jsonl")"
assert_contains "$out" '"insight":"edit *.go and * then"'
assert_not_contains "$out" 'home'
assert_not_contains "$out" 'Makefile'
t_end
t_begin "an insight that still holds a slash after reduction is dropped and logged"
repo="$(tmpdir)"; git -C "$repo" init -q -b main; mkdir -p "$repo/.bearing/state"
before="$(wc -l < "$g/bearing/learnings.jsonl" | tr -d ' ')"
( cd "$repo" && bash "$L" log --kind manual --skill go --key b --insight "see the src/ folder" )
assert_eq "$before" "$(wc -l < "$g/bearing/learnings.jsonl" | tr -d ' ')" "nothing stored"
assert_not_contains "$(cat "$g/bearing/learnings.jsonl")" 'folder'
assert_contains "$(cat "$repo/.bearing/state/gates.log")" "learn	not-run"
t_end
t_begin "add stores a manual entry and list reads it"
bash "$L" add "run the linter first" --skill general >/dev/null
assert_exit 0 bash "$L" list
assert_contains "$T_OUT" "run the linter first"
assert_exit 0 bash "$L" top --skills "go" --n 5
assert_contains "$T_OUT" "- run the linter first (1x)"
t_end
unset XDG_CONFIG_HOME

t_begin "guard session asks once when unanswered and reads back when on"
r2="$(tmpdir)"; git -C "$r2" init -q -b feat/X-1; mkdir -p "$r2/.bearing"
c2="$(tmpdir)"
gs() { ( cd "$r2" && XDG_CONFIG_HOME="$c2" BEARING_NO_GATE_LOG=1 bash "$GUARD" session --id s1 --source "${1:-startup}" ); }
assert_exit 0 gs startup
assert_contains "$T_OUT" "BEARING_LEARNING: ask."
assert_contains "$T_OUT" "Nothing leaves this machine."
assert_exit 0 gs resume
assert_not_contains "$T_OUT" "BEARING_LEARNING"
mkdir -p "$c2/bearing"; echo BEARING_LEARNING=on > "$c2/bearing/bearing.env"
for i in 1 2 3 4 5 6 7; do XDG_CONFIG_HOME="$c2" bash "$L" log --kind manual --skill general --key "k$i" --insight "tip $i"; done
assert_exit 0 gs startup
assert_contains "$T_OUT" "Learnings for the next step:"
assert_eq 5 "$(printf '%s\n' "$T_OUT" | grep -c '^- tip')" "at most five"
assert_not_contains "$T_OUT" "BEARING_LEARNING: ask"
t_end

t_begin "a rerun within ten minutes is logged"
c3="$(tmpdir)"; mkdir -p "$c3/bearing"; echo BEARING_LEARNING=on > "$c3/bearing/bearing.env"
ts() { ( cd "$r2" && XDG_CONFIG_HOME="$c3" bash "$KIT/plugins/bearing/bin/brg-session" timeline-start --id s9 --skill "$1" ); }
ts prd; ts prd
assert_contains "$(cat "$c3/bearing/learnings.jsonl")" '"kind":"rerun"'
ts prd
assert_contains "$(cat "$c3/bearing/learnings.jsonl")" '"count":2'
n="$(wc -l < "$c3/bearing/learnings.jsonl" | tr -d ' ')"
ts adr; ts adr
assert_eq "$((n+1))" "$(wc -l < "$c3/bearing/learnings.jsonl" | tr -d ' ')" "a switch of skill is not a rerun; only the repeat adds a key"
t_end

t_begin "a blocked check-file logs a gate block and keeps its exit code"
c4="$(tmpdir)"; mkdir -p "$c4/bearing"; echo BEARING_LEARNING=on > "$c4/bearing/bearing.env"
r4="$(tmpdir)"; git -C "$r4" init -q -b main
printf 'check-file:\n\t@echo "bad thing"; exit 1\n' > "$r4/Makefile"; echo x > "$r4/a.zz"
( cd "$r4" && XDG_CONFIG_HOME="$c4" bash "$GUARD" check-file "$r4/a.zz" ) >/dev/null 2>&1; rc=$?
assert_eq 2 "$rc" "exit 2 kept"
assert_contains "$(cat "$c4/bearing/learnings.jsonl")" '"skill":"check-file"'
assert_contains "$(cat "$c4/bearing/learnings.jsonl")" '*.zz'
t_end
t_summary
