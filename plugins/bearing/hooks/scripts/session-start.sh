#!/usr/bin/env bash
# SessionStart (startup, resume, compact): adapter over bin/brg-guard session.
# After a compaction the guard also prints the snapshot precompact wrote, and
# Claude Code adds this output to the model's context.
set -u
# No program runs before lib.sh resets the environment, so no dirname here;
# the next script starts with "$BASH" from ${0%/*}, never found on PATH.
# shellcheck source=lib.sh
case "$0" in (*/*) . "${0%/*}/lib.sh" ;; (*) . ./lib.sh ;; esac
exec "$BASH" "${0%/*}/../../bin/brg-guard" session --id "$(json_field session_id)" --source "$(json_field source)"
exit 2
