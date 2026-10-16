#!/usr/bin/env bash
# tests/unit/lint_skill_size.sh: the size lint fails on a 201-line skill and on
# zero skills, and passes with counts otherwise.
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
assert_contains "$T_OUT" "lint-skill-size: 1 skills, largest plugins/p/skills/a/SKILL.md 200"
t_end
t_begin "zero skills fails"
rm -rf "$w/plugins/p/skills/a"
assert_exit 2 make -s -C "$w" lint-skill-size
assert_contains "$T_OUT" "0 skills"
t_end
t_summary
