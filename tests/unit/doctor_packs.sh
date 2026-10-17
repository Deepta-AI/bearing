#!/usr/bin/env bash
# tests/unit/doctor_packs.sh: doctor checks the impeccable pack. Required on
# the standard and full profiles (MISSING with the pinned install command),
# optional on minimal, and an installed copy under ~/.claude or ~/.agents
# reports the version from its SKILL.md metadata. Fake HOME, real brg-doctor.
set -u
. "$(dirname "$0")/../lib/assert.sh"
D="$KIT/plugins/bearing/bin/brg-doctor"
repo="$(tmpdir)"; home="$(tmpdir)"
git -C "$repo" init -q -b main

t_begin "standard profile without impeccable is MISSING with the install command"
out="$(cd "$repo" && HOME="$home" BEARING_PROFILE=standard bash "$D" 2>&1)"
assert_contains "$out" "MISSING   impeccable not installed (bash install.sh, or npx --yes skills@"
assert_contains "$out" "add pbakaus/impeccable#"
t_end

t_begin "minimal profile: impeccable is optional"
out="$(cd "$repo" && HOME="$home" BEARING_PROFILE=minimal bash "$D" 2>&1)"
assert_contains "$out" "optional  impeccable not installed"
t_end

t_begin "an installed copy under ~/.claude or ~/.agents reports its version"
mkdir -p "$home/.agents/skills/impeccable"
printf -- '---\nname: impeccable\nmetadata:\n  version: 4.5.2\n---\n' > "$home/.agents/skills/impeccable/SKILL.md"
out="$(cd "$repo" && HOME="$home" BEARING_PROFILE=standard bash "$D" 2>&1)"
assert_contains "$out" "ok        impeccable 4.5.2"
t_end
t_summary
