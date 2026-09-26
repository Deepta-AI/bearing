#!/usr/bin/env bash
# PostToolUse (Edit|Write|MultiEdit): format the file, then lint it
# (bin/brg-guard format, then check-file). Problems go back to Claude as
# {"decision": "block"} with the tool's output, so it fixes them now rather
# than at make check; the edit itself has already happened. The formatter's
# note goes to stderr: Claude Code only reads stdout as a decision when the
# JSON is all of it.
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
guard="$(dirname "$0")/../../bin/brg-guard"
file="$(json_field tool_input.file_path)"
bash "$guard" format "$file" >&2
block_or_print "$guard" check-file "$file"
