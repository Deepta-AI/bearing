#!/usr/bin/env bash
# Stop: adapter over bin/brg-guard stop-gate. When files this session changed
# have not passed make check, Claude is sent back once with the reason
# ({"decision": "block"}); on the second stop (stop_hook_active) the guard
# only reminds, so the hook can never loop.
set -u
# No program runs before lib.sh resets the environment, so no dirname here;
# the next script starts with "$BASH" from ${0%/*}, never found on PATH.
# shellcheck source=lib.sh
case "$0" in (*/*) . "${0%/*}/lib.sh" ;; (*) . ./lib.sh ;; esac
guard="${0%/*}/../../bin/brg-guard"
set -- --id "$(json_field session_id)"
[ "$(json_field stop_hook_active)" = "true" ] && set -- "$@" --active
"$BASH" "${0%/*}/../../bin/brg-session" timeline-close --id "$(json_field session_id)" >/dev/null 2>&1
"$BASH" "${0%/*}/../../bin/brg-session" checkpoint >/dev/null 2>&1
block_or_print "$guard" stop-gate "$@"
