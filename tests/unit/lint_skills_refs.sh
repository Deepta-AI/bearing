#!/usr/bin/env bash
# tests/unit/lint_skills_refs.sh: lint-skills resolves a `references/x.md` or
# `templates/x` citation, and the plugin-root form
# `${CLAUDE_PLUGIN_ROOT}/references/x.md`, against the skill's own plugin, and
# fails a citation that does not exist (the plugin-root form is not looked up in
# another plugin).
set -u
. "$(dirname "$0")/../lib/assert.sh"
w="$(tmpdir)"
cp "$KIT/Makefile" "$w/Makefile"; cp -R "$KIT/bin" "$w/bin"; cp -R "$KIT/plugins" "$w/plugins"
sk="$w/plugins/bearing/skills/start-task/SKILL.md"
other="$w/plugins/bearing-apps/skills/react/SKILL.md"
cite() { printf '\n`%s`\n' "$2" >> "$1"; }
t_begin "the unmodified tree passes and prints counts"
assert_exit 0 mk -s -C "$w" lint-skills
assert_contains "$T_OUT" "lint-skills: "
assert_contains "$T_OUT" " skills ("
t_end
t_begin "a plugin-root citation of an existing file passes"
cite "$sk" '${CLAUDE_PLUGIN_ROOT}/references/console.md'
assert_exit 0 mk -s -C "$w" lint-skills
t_end
t_begin "a plugin-root citation of a missing file fails and is named"
cite "$sk" '${CLAUDE_PLUGIN_ROOT}/references/no-such.md'
assert_exit 2 mk -s -C "$w" lint-skills
assert_contains "$T_OUT" 'missing reference in start-task: ${CLAUDE_PLUGIN_ROOT}/references/no-such.md'
t_end
t_begin "the plugin-root form is resolved in the skill's own plugin only"
cp "$KIT/plugins/bearing/skills/start-task/SKILL.md" "$sk"
cite "$other" '${CLAUDE_PLUGIN_ROOT}/references/console.md'
assert_exit 2 mk -s -C "$w" lint-skills
assert_contains "$T_OUT" 'missing reference in react: ${CLAUDE_PLUGIN_ROOT}/references/console.md'
t_end
t_begin "a skill-relative citation of a missing file still fails"
cp "$KIT/plugins/bearing-apps/skills/react/SKILL.md" "$other"
cite "$other" 'references/no-such-either.md'
assert_exit 2 mk -s -C "$w" lint-skills
assert_contains "$T_OUT" "missing reference in react: references/no-such-either.md"
t_end
t_summary
