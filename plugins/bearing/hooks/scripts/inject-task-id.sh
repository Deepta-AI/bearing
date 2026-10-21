#!/usr/bin/env bash
# UserPromptSubmit: adapter over bin/brg-guard task-id.
set -u
# No program runs before lib.sh resets the environment, so no dirname here;
# the next script starts with "$BASH" from ${0%/*}, never found on PATH.
# shellcheck source=lib.sh
case "$0" in (*/*) . "${0%/*}/lib.sh" ;; (*) . ./lib.sh ;; esac
exec "$BASH" "${0%/*}/../../bin/brg-guard" task-id "$(json_field prompt)"
exit 2
