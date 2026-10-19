#!/usr/bin/env bash
# PreToolUse (Skill): record which skill started, for resume and the menu.
set -u
# No program runs before lib.sh resets the environment, so no dirname here;
# the next script starts with "$BASH" from ${0%/*}, never found on PATH.
# shellcheck source=lib.sh
case "$0" in (*/*) . "${0%/*}/lib.sh" ;; (*) . ./lib.sh ;; esac
s="$(json_field tool_input.skill)"
if [ "$s" = "__BRG_UNPARSED__" ]; then
  "$BASH" "${0%/*}/../../bin/brg-session" not-run --skill unparsed >/dev/null 2>&1
  exit 0
fi
exec "$BASH" "${0%/*}/../../bin/brg-session" timeline-start --id "$(json_field session_id)" --skill "$s"
exit 2
