#!/usr/bin/env bash
# Stop: adapter over bin/brg-guard stop-gate. When files this session changed
# have not passed make check, Claude is sent back once with the reason
# ({"decision": "block"}); on the second stop (stop_hook_active) the guard
# only reminds, so the hook can never loop.
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
guard="$(dirname "$0")/../../bin/brg-guard"
set -- --id "$(json_field session_id)"
[ "$(json_field stop_hook_active)" = "true" ] && set -- "$@" --active
block_or_print "$guard" stop-gate "$@"
