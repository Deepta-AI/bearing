#!/usr/bin/env bash
# tests/unit/doctor_gate_health.sh: brg-doctor's gate health line, from the
# last 14 days of .bearing/state/gates.log. A Stop gate that blocked 10 times
# or more and more often than it passed is MISSING, as is a compaction
# snapshot that failed to write; older lines do not count; an empty, missing
# or linked log is optional, never a pass.
set -u
. "$(dirname "$0")/../lib/assert.sh"
DOCTOR="$KIT/plugins/bearing/bin/brg-doctor"

repo="$(tmpdir)"
git -C "$repo" init -q -b main
mkdir -p "$repo/.bearing/state"
log="$repo/.bearing/state/gates.log"
fh="$(tmpdir)"
now="$(date +%Y-%m-%dT%H:%M:%S)"
lines() { # lines <n> <time> <gate> <outcome>: append n gates.log lines
  local i=0; while [ "$i" -lt "$1" ]; do printf '%s\t%s\t%s\t12\t\n' "$2" "$3" "$4" >> "$log"; i=$((i+1)); done
}
health() { ( cd "$repo" && env HOME="$fh" bash "$DOCTOR" 2>&1 ) | grep 'gate health' ; }

t_begin "no log, an empty log and a linked log are optional"
assert_contains "$(health)" "optional  gate health: no .bearing/state/gates.log yet"
: > "$log"
assert_contains "$(health)" "optional  gate health: 0 gate decisions in the last 14 days"
other="$(tmpdir)/gates.log"; lines 20 "$now" stop-gate blocked; mv "$log" "$other"; ln -s "$other" "$log"
assert_contains "$(health)" "optional  gate health: no .bearing/state/gates.log yet" "a link is not read"
rm -f "$log"
t_end

t_begin "a Stop gate that blocks more than it passes is MISSING, with both counts"
lines 12 "$now" stop-gate blocked; lines 3 "$now" stop-gate passed; lines 5 "$now" command allowed
assert_contains "$(health)" "MISSING   gate health: the Stop gate blocked 12 times and passed 3 in 14 days"
assert_exit 1 bash -c "cd '$repo' && HOME='$fh' bash '$DOCTOR' >/dev/null 2>&1"
t_end

t_begin "under ten blocks, or more passes than blocks, is ok and counts every line"
: > "$log"; lines 9 "$now" stop-gate blocked; lines 1 "$now" command refused
assert_contains "$(health)" "ok        gate health: 10 gate decisions in 14 days, Stop gate blocked 9, passed 0"
: > "$log"; lines 12 "$now" stop-gate blocked; lines 13 "$now" stop-gate passed
assert_contains "$(health)" "ok        gate health: 25 gate decisions in 14 days, Stop gate blocked 12, passed 13"
t_end

t_begin "lines older than 14 days do not count, in gates.log.1 too"
: > "$log"; lines 30 "2026-01-02T03:04:05" stop-gate blocked; lines 2 "$now" stop-gate passed
printf '2026-01-01T00:00:00\tstop-gate\tblocked\t9\t\n' > "$log.1"
assert_contains "$(health)" "ok        gate health: 2 gate decisions in 14 days, Stop gate blocked 0, passed 2"
rm -f "$log.1"
t_end

t_begin "a failed compaction snapshot is MISSING"
: > "$log"; lines 1 "$now" precompact failed
assert_contains "$(health)" "MISSING   gate health: 1 compaction snapshot(s) failed to write in 14 days"
t_end

t_summary
