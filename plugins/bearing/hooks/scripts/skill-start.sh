#!/usr/bin/env bash
# PreToolUse (Skill): record which skill started, for resume and the menu.
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
s="$(json_field tool_input.skill)"; [ "$s" != "__BRG_UNPARSED__" ] || exit 0
exec bash "$(dirname "$0")/../../bin/brg-session" timeline-start --id "$(json_field session_id)" --skill "$s"
