#!/usr/bin/env bash
# tests/unit/push_settings.sh: the settings template denies edits to
# ~/.config/bearing, ~/.gitconfig and ~/.config/git and the brg-push run
# verb, keeps the push deny, and AGENTS.md rule 2 and the hooks description
# name the opt-in push.
set -u
. "$(dirname "$0")/../lib/assert.sh"

t_begin "the settings template denies edits to the user config and the run verb"
S="$KIT/plugins/bearing/templates/repo/.claude/settings.json"
deny="$(jq -r '.permissions.deny[]' "$S")"
assert_contains "$deny" "Edit(~/.config/bearing/**)"
assert_contains "$deny" "Edit(~/.gitconfig)"
assert_contains "$deny" "Edit(~/.config/git/**)"
assert_contains "$deny" "Bash(bash *bin/brg-push run*)"
assert_contains "$deny" "Bash(git push:*)"
assert_contains "$(cat "$KIT/plugins/bearing/templates/repo/AGENTS.md")" "BEARING_AUTO_PUSH"
dw="$(jq -r '.sandbox.filesystem.denyWrite[]' "$S")"
assert_contains "$dw" "~/.gitconfig"
assert_contains "$dw" "~/.config/git"
t_end

t_begin "the run deny is described as a first line, the guard as the control"
readme="$(jq -r '._readme[]' "$S")"
assert_contains "$readme" "BEARING_AUTO_PUSH"
assert_contains "$readme" "first line"
assert_contains "$readme" "brg-push run"
assert_contains "$readme" "push URL"
assert_contains "$readme" "fresh clone"
assert_not_contains "$readme" "pre-push hook's to judge"
assert_contains "$readme" "./bin/brg-push run"
assert_contains "$readme" "refuses every agent push unless PUSH_CONFIRM is off"
t_end

t_begin "the hooks description names the opt-in feature branch push"
desc="$(jq -r '.description' "$KIT/plugins/bearing/hooks/hooks.json")"
assert_contains "$desc" "except a task branch push the Stop hook makes where the engineer opted the repository in"
t_end

t_summary
