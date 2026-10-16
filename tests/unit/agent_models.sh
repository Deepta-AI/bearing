#!/usr/bin/env bash
# tests/unit/agent_models.sh: review agents default to sonnet except reviewer;
# the skills that need Opus ask for it by name.
set -u
. "$(dirname "$0")/../lib/assert.sh"
A="$KIT/plugins/bearing/agents"; S="$KIT/plugins/bearing/skills"
t_begin "agent defaults"
for a in verifier critic security-auditor; do assert_contains "$(grep '^model:' "$A/$a.md")" "sonnet" "$a"; done
assert_contains "$(grep '^model:' "$A/reviewer.md")" "opus" "reviewer"
t_end
t_begin "skills ask for opus where severity needs it"
assert_contains "$(cat "$S/branch-review/SKILL.md")" 'model: "opus"' "branch-review Critical"
assert_contains "$(cat "$S/vapt-report/SKILL.md")" 'model: "opus"' "vapt-report"
assert_contains "$(tr '\n' ' ' < "$S/vapt-report/SKILL.md" | tr -s ' ')" 'security-auditor and each verifier call pass model: "opus"' "vapt-report auditor too"
assert_contains "$(cat "$S/high-level-design/SKILL.md")" 'model: "opus"' "graded critic"
t_end
t_summary
