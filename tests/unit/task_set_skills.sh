#!/usr/bin/env bash
# tests/unit/task_set_skills.sh: the five skills cite the task-set reference,
# and each stays at 200 lines or fewer. Counts the skills; fails on zero.
set -u
. "$(dirname "$0")/../lib/assert.sh"
R='${CLAUDE_PLUGIN_ROOT}/references/task-set.md'
n=0
t_begin "the reference exists and holds the rules"
f="$KIT/plugins/bearing/references/task-set.md"; assert_file "$f"
body="$(cat "$f")"
for h in "## Start" "## Branch names" "## State and progress" "## Merge order" "## One MR per repository" "## Finish"; do assert_contains "$body" "$h"; done
t_end
t_begin "the five skills cite it"
for s in start-task session-handoff definition-of-done merge-request autopilot; do
  n=$((n+1)); f="$KIT/plugins/bearing/skills/$s/SKILL.md"
  assert_contains "$(cat "$f")" "$R" "$s cites task-set.md"
  assert_eq 1 "$([ "$(wc -l < "$f")" -le 200 ] && echo 1 || echo 0)" "$s at most 200 lines"
done
assert_eq 5 "$n" "five skills checked"
t_end
t_begin "start-task takes --repos; definition-of-done names no item count"
st="$(cat "$KIT/plugins/bearing/skills/start-task/SKILL.md")"
assert_contains "$(printf '%s\n' "$st" | grep '^argument-hint:')" "[--repos Name,Name,...]" "argument-hint has --repos"
assert_contains "$st" 'Set: <n> repos, merge order' "start-task output contract has the Set line"
dod="$(cat "$KIT/plugins/bearing/skills/definition-of-done/SKILL.md")"
assert_contains "$dod" "the items in step 3" "Inputs counts no items"
assert_contains "$(printf '%s\n' "$dod" | grep '^allowed-tools:')" "Bash(python3 *skills/session-handoff/scripts/progress.py*)" "dod grants progress.py"
mr="$(cat "$KIT/plugins/bearing/skills/merge-request/SKILL.md")"
assert_contains "$mr" 'Set: <k> of <n>; merge after: <Name> | first' "merge-request output contract has the Set line"
t_end
t_summary
