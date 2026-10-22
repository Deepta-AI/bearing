#!/usr/bin/env bash
# StopFailure: a turn ended on an API error (rate limit, overload, an auth or
# billing error). Claude Code gives this hook no say in what happens next, so
# it only makes the next session's resume work: the checkpoint brg-session
# writes for compaction is written now, and gates.log records the error type
# (`brg-guard stats` counts them). Always exits 0.
set -u
# No program runs before lib.sh resets the environment, so no dirname here;
# the next script starts with "$BASH" from ${0%/*}, never found on PATH.
# shellcheck source=lib.sh
case "$0" in (*/*) . "${0%/*}/lib.sh" ;; (*) . ./lib.sh ;; esac
e="$(json_field error)"
# The error type is a fixed word (rate_limit, server_error, ...); anything
# else is logged as unknown rather than written as given.
case "$e" in (*[!a-z_]*|'') e=unknown ;; esac
"$BASH" "${0%/*}/../../bin/brg-session" checkpoint >/dev/null 2>&1
"$BASH" "${0%/*}/../../bin/brg-guard" log stop-failure "$e" >/dev/null 2>&1
exit 0
