#!/usr/bin/env bash
# PreToolUse (Bash): adapter over bin/brg-guard command. Exit 2 blocks.
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
exec bash "$(dirname "$0")/../../bin/brg-guard" command "$(json_field tool_input.command)"
