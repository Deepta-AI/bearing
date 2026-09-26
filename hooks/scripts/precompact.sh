#!/usr/bin/env bash
# PreCompact (manual, auto): adapter over bin/brg-guard precompact, which
# writes the branch, changes, check state and the user's last requests to
# .bearing/state/<branch>.compact.md; SessionStart (compact) reads it back.
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
exec bash "$(dirname "$0")/../../bin/brg-guard" precompact "$(json_field transcript_path)"
