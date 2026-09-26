#!/usr/bin/env bash
# SessionStart (startup, resume, compact): adapter over bin/brg-guard session.
# After a compaction the guard also prints the snapshot precompact wrote, and
# Claude Code adds this output to the model's context.
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
exec bash "$(dirname "$0")/../../bin/brg-guard" session --id "$(json_field session_id)" --source "$(json_field source)"
