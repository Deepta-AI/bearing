#!/usr/bin/env bash
# PostToolUse (Edit|Write|MultiEdit): format the file with an allow-listed
# formatter (bin/brg-guard format), then print the one line brg-guard
# check-file gives: the per-file check was not run. Hooks run outside the
# sandbox and the working tree is the agent's, so this hook runs no
# repository command (no Makefile target, no node_modules binary); make
# check-file runs in the session, and the Stop gate holds the session to
# make check. The formatter's note goes to stderr, the check-file line to
# stdout; on the session's first edit both that line and brg-guard
# stop-hint's go to Claude as additionalContext instead.
set -u
# No program runs before lib.sh resets the environment, so no dirname here;
# the next script starts with "$BASH" from ${0%/*}, never found on PATH.
# shellcheck source=lib.sh
case "$0" in (*/*) . "${0%/*}/lib.sh" ;; (*) . ./lib.sh ;; esac
guard="${0%/*}/../../bin/brg-guard"
file="$(json_field tool_input.file_path)"
"$BASH" "$guard" format "$file" >&2
line="$("$BASH" "$guard" check-file "$file")"
# The first edit of a session also hears what the Stop gate will ask. Plain
# stdout from this hook reaches the transcript, not Claude, so that one line
# goes as additionalContext; every other edit prints as before.
hint="$("$BASH" "$guard" stop-hint --id "$(json_field session_id)" --file "$file")"
if [ -n "$hint" ] && command -v jq >/dev/null 2>&1; then
  jq -n --arg c "$hint${line:+
$line}" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $c}}'
else
  [ -n "$line" ] && printf '%s\n' "$line"
fi
exit 0
