#!/usr/bin/env bash
# PreToolUse (Bash): adapter over bin/brg-guard command. Exit 2 blocks.
set -u
# No program runs before lib.sh resets the environment, so no dirname here.
# shellcheck source=lib.sh
case "$0" in (*/*) . "${0%/*}/lib.sh" ;; (*) . ./lib.sh ;; esac
exec bash "$(dirname "$0")/../../bin/brg-guard" command "$(json_field tool_input.command)"
