#!/usr/bin/env bash
# tests/unit/lint_questions.sh: a skill that asks in prose fails; one that
# uses AskUserQuestion and cites console.md passes; "task:" is not "ask:";
# a question in a reference file counts; a phrase wrapped over two lines
# counts; zero skills fails.
set -u
. "$(dirname "$0")/../lib/assert.sh"
w="$(tmpdir)"; mkdir -p "$w/plugins/p/skills/a"; cp "$KIT/Makefile" "$w/Makefile"
printf -- '---\nname: a\nallowed-tools: Read\n---\nIf absent, ask the user once.\n' > "$w/plugins/p/skills/a/SKILL.md"
t_begin "prose fails"
assert_exit 2 make -s -C "$w" lint-questions
assert_contains "$T_OUT" "plugins/p/skills/a/SKILL.md"
t_end
t_begin "tool and contract pass"
printf -- '---\nname: a\nallowed-tools: Read, AskUserQuestion\n---\nIf absent, ask the user once (${CLAUDE_PLUGIN_ROOT}/references/console.md).\n' > "$w/plugins/p/skills/a/SKILL.md"
assert_exit 0 make -s -C "$w" lint-questions
assert_contains "$T_OUT" "lint-questions: 1 skills, 0 reference files, 1 ask the user, 0 in prose"
t_end
t_begin "task: is not ask:"
printf -- '---\nname: a\nallowed-tools: Read\n---\nThe subtask: do it. A mask: here. Then task: x.\n' > "$w/plugins/p/skills/a/SKILL.md"
assert_exit 0 make -s -C "$w" lint-questions
assert_contains "$T_OUT" "1 skills, 0 reference files, 0 ask the user"
t_end
t_begin "reference file asks in prose"
mkdir -p "$w/plugins/p/skills/a/references"; printf 'Ask: which one?\n' > "$w/plugins/p/skills/a/references/x.md"
assert_exit 2 make -s -C "$w" lint-questions
t_end
t_begin "wrapped over two lines"
w2="$(tmpdir)"; mkdir -p "$w2/plugins/p/skills/b"; cp "$KIT/Makefile" "$w2/Makefile"
printf -- '---\nname: b\nallowed-tools: Read\n---\nZero files: ask\n  once for the path.\n' > "$w2/plugins/p/skills/b/SKILL.md"
assert_exit 2 make -s -C "$w2" lint-questions
t_end
t_begin "ask one question"
w3="$(tmpdir)"; mkdir -p "$w3/plugins/p/skills/c"; cp "$KIT/Makefile" "$w3/Makefile"
printf -- '---\nname: c\nallowed-tools: Read\n---\nIf absent, ask one question.\n' > "$w3/plugins/p/skills/c/SKILL.md"
assert_exit 2 make -s -C "$w3" lint-questions
t_end
t_begin "half contract fails"
printf -- '---\nname: c\nallowed-tools: Read, AskUserQuestion\n---\nask once.\n' > "$w3/plugins/p/skills/c/SKILL.md"
assert_exit 2 make -s -C "$w3" lint-questions
printf -- '---\nname: c\nallowed-tools: Read\n---\nask once (references/console.md).\n' > "$w3/plugins/p/skills/c/SKILL.md"
assert_exit 2 make -s -C "$w3" lint-questions
t_end
t_begin "zero skills"
rm -rf "$w/plugins/p/skills/a"
assert_exit 2 make -s -C "$w" lint-questions
t_end
t_summary
