#!/usr/bin/env bash
# PostToolUse (Edit|Write|MultiEdit): format the file with an allow-listed
# formatter (bin/brg-guard format), then print the one line brg-guard
# check-file gives: the per-file check was not run. Hooks run outside the
# sandbox and the working tree is the agent's, so this hook runs no
# repository command (no Makefile target, no node_modules binary); make
# check-file runs in the session, and the Stop gate holds the session to
# make check. The formatter's note goes to stderr, the check-file line to
# stdout.
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
guard="$(dirname "$0")/../../bin/brg-guard"
file="$(json_field tool_input.file_path)"
bash "$guard" format "$file" >&2
bash "$guard" check-file "$file"
exit 0
