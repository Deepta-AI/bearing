#!/usr/bin/env bash
# tests/unit/lint_skill_size.sh: the size lint fails on a 201-line skill and on
# zero skills, honours bin/lint-skill-size.allow ceilings, fails stale entries,
# and passes with counts otherwise.
set -u
. "$(dirname "$0")/../lib/assert.sh"
w="$(tmpdir)"; mkdir -p "$w/plugins/p/skills/a"
cp "$KIT/Makefile" "$w/Makefile"
for i in $(seq 1 201); do echo "l$i"; done > "$w/plugins/p/skills/a/SKILL.md"
t_begin "201 lines fails"
assert_exit 2 make -s -C "$w" lint-skill-size
assert_contains "$T_OUT" "plugins/p/skills/a/SKILL.md 201"
t_end
t_begin "200 lines passes with a count"
for i in $(seq 1 200); do echo "l$i"; done > "$w/plugins/p/skills/a/SKILL.md"
assert_exit 0 make -s -C "$w" lint-skill-size
assert_contains "$T_OUT" "lint-skill-size: 1 skills, 0 allowed over 200 (none), largest plugins/p/skills/a/SKILL.md 200"
t_end
t_begin "an allowed skill at its ceiling passes and is named"
mkdir -p "$w/plugins/p/skills/a" "$w/bin"
for i in $(seq 1 205); do echo "l$i"; done > "$w/plugins/p/skills/a/SKILL.md"
echo "plugins/p/skills/a/SKILL.md|205|test reason" > "$w/bin/lint-skill-size.allow"
assert_exit 0 make -s -C "$w" lint-skill-size
assert_contains "$T_OUT" "1 skills, 1 allowed over 200 (plugins/p/skills/a/SKILL.md), largest plugins/p/skills/a/SKILL.md 205"
t_end
t_begin "one line above the ceiling fails"
for i in $(seq 1 206); do echo "l$i"; done > "$w/plugins/p/skills/a/SKILL.md"
assert_exit 2 make -s -C "$w" lint-skill-size
assert_contains "$T_OUT" "over its ceiling of 205 lines: plugins/p/skills/a/SKILL.md 206"
t_end
t_begin "an allow entry for a skill at or under 200 is stale"
for i in $(seq 1 200); do echo "l$i"; done > "$w/plugins/p/skills/a/SKILL.md"
assert_exit 2 make -s -C "$w" lint-skill-size
assert_contains "$T_OUT" "stale allow entry"
t_end
t_begin "an allow entry for a missing file is stale"
echo "plugins/p/skills/gone/SKILL.md|210|gone" >> "$w/bin/lint-skill-size.allow"
for i in $(seq 1 205); do echo "l$i"; done > "$w/plugins/p/skills/a/SKILL.md"
assert_exit 2 make -s -C "$w" lint-skill-size
assert_contains "$T_OUT" "stale allow entry (file does not exist): plugins/p/skills/gone/SKILL.md"
t_end
t_begin "zero skills fails"
rm -rf "$w/plugins/p/skills/a"
assert_exit 2 make -s -C "$w" lint-skill-size
assert_contains "$T_OUT" "0 skills"
t_end
t_summary
