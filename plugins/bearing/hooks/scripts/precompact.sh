#!/usr/bin/env bash
# PreCompact (manual, auto): adapter over bin/brg-guard precompact, which
# writes the branch, changes, check state and the user's last requests to
# .bearing/state/<branch>.compact.md; SessionStart (compact) reads it back.
set -u
# No program runs before lib.sh resets the environment, so no dirname here.
# shellcheck source=lib.sh
case "$0" in (*/*) . "${0%/*}/lib.sh" ;; (*) . ./lib.sh ;; esac
bash "$(dirname "$0")/../../bin/brg-session" checkpoint >/dev/null 2>&1
exec bash "$(dirname "$0")/../../bin/brg-guard" precompact "$(json_field transcript_path)"
