#!/usr/bin/env bash
# tests/unit/critique_unattended.sh: an unattended run never asks. design-critique
# checks all three unattended signals of references/impeccable.md (--unattended,
# printenv, brg-config get noninteractive --user) and grants each command;
# screen-design and design-critique take --unattended; autopilot's ux and
# design_review stage text passes it to both, as it does to design-directions.
set -u
. "$(dirname "$0")/../lib/assert.sh"
P="$KIT/plugins/bearing"
DC="$P/skills/design-critique/SKILL.md"
SD="$P/skills/screen-design/SKILL.md"

t_begin "design-critique checks and grants all three unattended signals"
fm="$(sed -n '/^---$/,/^---$/p' "$DC")"
body="$(cat "$DC")"
assert_contains "$fm" "Bash(printenv BEARING_AUTOPILOT BEARING_NONINTERACTIVE)" "printenv grant"
assert_contains "$fm" "Bash(bash *bin/brg-config get noninteractive --user)" "brg-config grant"
assert_contains "$body" 'bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-config" get noninteractive --user' "brg-config signal"
assert_contains "$body" "printenv BEARING_AUTOPILOT BEARING_NONINTERACTIVE" "printenv signal"
assert_contains "$(grep '^argument-hint:' "$DC")" "--unattended" "design-critique argument-hint"
t_end

t_begin "screen-design takes --unattended"
assert_contains "$(grep '^argument-hint:' "$SD")" "--unattended" "screen-design argument-hint"
t_end

t_begin "autopilot passes --unattended to screen-design and design-critique"
ap="$(cat "$P/bin/brg-autopilot")"
assert_contains "$ap" "screen-design --unattended" "ux stage text"
assert_contains "$ap" "design-critique --unattended" "design_review stage text"
assert_contains "$(cat "$P/skills/autopilot/references/design-stages.md")" "screen-design --unattended" "design-stages.md"
assert_contains "$(cat "$P/skills/autopilot/references/build-and-after.md")" "design-critique --unattended" "build-and-after.md"
t_end

t_summary
