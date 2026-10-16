#!/usr/bin/env bash
# PreToolUse (Skill): record which skill started, for resume and the menu.
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
s="$(json_field tool_input.skill)"
if [ "$s" = "__BRG_UNPARSED__" ]; then
  bash "$(dirname "$0")/../../bin/brg-session" not-run --skill unparsed >/dev/null 2>&1
  exit 0
fi
exec bash "$(dirname "$0")/../../bin/brg-session" timeline-start --id "$(json_field session_id)" --skill "$s"
