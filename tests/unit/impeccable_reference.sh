#!/usr/bin/env bash
# tests/unit/impeccable_reference.sh: the shared impeccable reference
# (plugins/bearing/references/impeccable.md) carries Detect, Invoke, the
# unattended rule, the commands table and one filled section per calling
# skill, and design-directions follows it: one impeccable round recorded in
# approved.json as source, chosen and challengers, the fallback named, the
# grants it needs, and SKILL.md at or under 200 lines.
set -u
. "$(dirname "$0")/../lib/assert.sh"

REF="$KIT/plugins/bearing/references/impeccable.md"
SK="$KIT/plugins/bearing/skills/design-directions/SKILL.md"

t_begin "reference exists with its sections"
assert_file "$REF"
body="$(cat "$REF" 2>/dev/null)"
for h in '## Detect' '## Invoke' '## Unattended' '## Commands' '## Inferred facts' \
         '## design-directions' '## design-system' '## screen-design' '## design-critique'; do
  assert_contains "$body" "$h" "impeccable.md"
done
t_end

t_begin "every skill section holds text, none defers to a later task"
for s in design-directions design-system screen-design design-critique; do
  n="$(awk -v h="## $s" '$0==h{on=1;next} /^## /{on=0} on && NF{c++} END{print c+0}' "$REF" 2>/dev/null)"
  ok=no; [ "${n:-0}" -ge 3 ] && ok=yes; assert_eq yes "$ok" "section $s has 3 or more lines (got ${n:-0})"
done
assert_not_contains "$body" "Task " "impeccable.md names a plan task"
assert_not_contains "$body" "TODO" "impeccable.md"
t_end

t_begin "commands table names who asks"
for c in '`init`' '`document --seed`' '`polish`' '`harden`' '`audit`' '`critique`'; do
  assert_contains "$body" "| $c |" "commands table"
done
row="$(grep -F '| `critique` |' "$REF" 2>/dev/null)"
assert_contains "$row" "not run" "critique row"
row="$(grep -F '| `audit` |' "$REF" 2>/dev/null)"
assert_contains "$row" "| run" "audit row"
assert_contains "$body" "BEARING_NONINTERACTIVE" "unattended rule"
assert_contains "$body" "BEARING_AUTOPILOT" "unattended rule"
assert_contains "$body" "--unattended" "unattended rule"
assert_contains "$body" "impeccable not installed" "detect fallback line"
t_end

t_begin "design-directions follows the reference"
sk="$(cat "$SK")"
assert_contains "$sk" '${CLAUDE_PLUGIN_ROOT}/references/impeccable.md' "SKILL.md"
for f in '`source`' '`chosen`' '`challengers`'; do assert_contains "$sk" "$f" "SKILL.md approved.json"; done
assert_contains "$sk" "impeccable not installed" "SKILL.md fallback"
assert_contains "$sk" "unattended: Bearing's doctrine" "SKILL.md fallback"
assert_contains "$sk" "Path: impeccable" "output contract"
assert_contains "$sk" "Impeccable:" "output contract"
fm="$(sed -n '/^---$/,/^---$/p' "$SK")"
assert_contains "$fm" " Skill," "allowed-tools"
assert_contains "$fm" "Bash(printenv BEARING_AUTOPILOT BEARING_NONINTERACTIVE)" "allowed-tools"
assert_contains "$fm" "Bash(rm DESIGN.md)" "allowed-tools"
lines="$(wc -l < "$SK" | tr -d ' ')"
ok=no; [ "$lines" -le 200 ] && ok=yes; assert_eq yes "$ok" "SKILL.md at or under 200 lines (got $lines)"
t_end

t_summary
