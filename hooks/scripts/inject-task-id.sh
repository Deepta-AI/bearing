#!/usr/bin/env bash
# UserPromptSubmit: adapter over bin/brg-guard task-id.
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
exec bash "$(dirname "$0")/../../bin/brg-guard" task-id "$(json_field prompt)"
