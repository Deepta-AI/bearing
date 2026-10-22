#!/usr/bin/env bash
# PostToolUseFailure and PermissionDenied: record in gates.log which tool
# failed or was denied, so `brg-guard stats` shows where sessions lose time.
# The event name comes from the hook input; only the tool name is logged,
# never its input, error text or the denial reason (they can hold paths and
# secrets). Never blocks: the tool already failed or was denied. Always exits 0.
set -u
# No program runs before lib.sh resets the environment, so no dirname here;
# the next script starts with "$BASH" from ${0%/*}, never found on PATH.
# shellcheck source=lib.sh
case "$0" in (*/*) . "${0%/*}/lib.sh" ;; (*) . ./lib.sh ;; esac
case "$(json_field hook_event_name)" in
  (PermissionDenied) gate=permission-denied ;;
  (*) gate=tool-failure ;;
esac
t="$(json_field tool_name)"
# A tool name is a word (Bash, Edit, mcp__server__tool); anything else is
# logged as unknown.
case "$t" in (*[!A-Za-z0-9_-]*|'') t=unknown ;; esac
"$BASH" "${0%/*}/../../bin/brg-guard" log "$gate" "$t" >/dev/null 2>&1
exit 0
