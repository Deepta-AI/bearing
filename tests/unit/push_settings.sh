#!/usr/bin/env bash
# tests/unit/push_settings.sh: the settings template denies edits to
# ~/.config/bearing, ~/.gitconfig and ~/.config/git, Edit and Write to .git,
# ~/.local/bin, ~/go/bin, ~/.config/git and the user-owned hook PATH
# directories (Homebrew, /usr/local/bin, Linuxbrew), Edit, Write and Bash writes to
# the project and user Claude Code settings files, and the brg-push run
# verb, keeps the push deny, and AGENTS.md rule 2 and the hooks description
# name the opt-in push.
set -u
. "$(dirname "$0")/../lib/assert.sh"

t_begin "the settings template denies edits to the user config and the run verb"
S="$KIT/plugins/bearing/templates/repo/.claude/settings.json"
deny="$(jq -r '.permissions.deny[]' "$S")"
readme_all="$(jq -r '._readme[]' "$S")"
assert_contains "$deny" "Edit(~/.config/bearing/**)"
assert_contains "$deny" "Edit(~/.gitconfig)"
assert_contains "$deny" "Edit(~/.config/git/**)"
assert_contains "$deny" "Bash(bash *bin/brg-push run*)"
assert_contains "$deny" "Bash(git push:*)"
# The sandbox covers Bash only; Edit and Write (autopilot's child has both,
# unscoped) are denied what a hook later reads or runs outside the sandbox.
for p in "./.git/**" "**/.git/**" "~/.local/bin/**" "~/go/bin/**" "~/.config/git/**"; do
  for tool in Edit Write; do
    assert_eq 1 "$(printf '%s\n' "$deny" | grep -cxF "$tool($p)")" "$tool($p) denied"
  done
done
assert_contains "$(cat "$KIT/plugins/bearing/templates/repo/AGENTS.md")" "BEARING_AUTO_PUSH"
dw="$(jq -r '.sandbox.filesystem.denyWrite[]' "$S")"
assert_contains "$dw" "~/.gitconfig"
assert_contains "$dw" "~/.config/git"
t_end

t_begin "the settings files whose env reaches the hooks are denied to Edit, Write and Bash"
# A settings file's env (BASH_ENV, PATH) is the hooks' environment, and hooks
# run outside the sandbox: the agent edits none of them.
n=0
for p in ./.claude/settings.json ./.claude/settings.local.json "~/.claude/settings.json" "~/.claude/settings.local.json"; do
  for tool in Edit Write; do
    assert_eq 1 "$(printf '%s\n' "$deny" | grep -cxF "$tool($p)")" "$tool($p) denied"
    n=$((n+1))
  done
done
assert_eq 8 "$n" "settings denies checked"
for p in ./.claude/settings.json ./.claude/settings.local.json; do
  assert_eq 1 "$(printf '%s\n' "$dw" | grep -cxF "$p")" "$p in sandbox denyWrite"
done
t_end

t_begin "the directories on the hook PATH that a user owns are denied to Edit and Write"
# Hooks find jq, git and python3 on a fixed PATH; Homebrew and Linuxbrew
# directories are often the user's own, so the agent writes none of them.
n=0
for p in "//opt/homebrew/bin/**" "//usr/local/bin/**" "//home/linuxbrew/.linuxbrew/bin/**"; do
  for tool in Edit Write; do
    assert_eq 1 "$(printf '%s\n' "$deny" | grep -cxF "$tool($p)")" "$tool($p) denied"
    n=$((n+1))
  done
done
assert_eq 6 "$n" "hook PATH denies checked"
assert_contains "$readme_all" "hook PATH"
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
