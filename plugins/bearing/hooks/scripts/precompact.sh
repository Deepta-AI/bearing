#!/usr/bin/env bash
# PreCompact (manual, auto): adapter over bin/brg-guard precompact, which
# writes the branch, changes, check state and the user's last requests to
# .bearing/state/<branch>.compact.md; SessionStart (compact) reads it back.
set -u
# No program runs before lib.sh resets the environment, so no dirname here;
# the next script starts with "$BASH" from ${0%/*}, never found on PATH.
# shellcheck source=lib.sh
case "$0" in (*/*) . "${0%/*}/lib.sh" ;; (*) . ./lib.sh ;; esac
"$BASH" "${0%/*}/../../bin/brg-session" checkpoint >/dev/null 2>&1
exec "$BASH" "${0%/*}/../../bin/brg-guard" precompact "$(json_field transcript_path)"
exit 2
