#!/usr/bin/env bash
# tests/unit/guard_timing.sh: format writes a timed gates.log line; stats
# prints median and p90; doctor --timing prints the stats block.
set -u
. "$(dirname "$0")/../lib/assert.sh"
unset BEARING_NO_GATE_LOG # this test reads gates.log

repo="$(tmpdir)"
git -C "$repo" init -q -b main
mkdir -p "$repo/.bearing/state"
printf 'echo hi\n' > "$repo/a.sh"
in_repo() { ( cd "$repo" && bash "$GUARD" "$@" ) }

t_begin "format logs a timed line"
assert_exit 0 in_repo format "$repo/a.sh"
log="$(cat "$repo/.bearing/state/gates.log")"
assert_contains "$log" "	format	"
t_end

t_begin "stats prints median and p90"
printf '2026-10-16T10:00:0%s\tcheck-file\tclean\t%s\t\n' 1 10 2 20 3 30 4 40 5 1000 > "$repo/.bearing/state/gates.log"
assert_exit 0 in_repo stats
assert_contains "$T_OUT" "check-file clean"
assert_contains "$T_OUT" "median    30 ms"
assert_contains "$T_OUT" "p90  1000 ms"
t_end

t_begin "doctor --timing prints the block"
assert_exit 0 bash -c "cd '$repo' && bash '$KIT/plugins/bearing/bin/brg-doctor' --timing"
assert_contains "$T_OUT" "timing:"
assert_contains "$T_OUT" "check-file clean"
t_end

t_summary
