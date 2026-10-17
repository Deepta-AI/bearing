#!/usr/bin/env bash
# tests/unit/screen_impeccable.sh: screen-design runs impeccable harden then
# polish before its own gates, grants every command Detect and Unattended
# run, states the unattended polish rule, and stays at or under 200 lines.
set -u
. "$(dirname "$0")/../lib/assert.sh"

SK="$KIT/plugins/bearing/skills/screen-design/SKILL.md"
REF="$KIT/plugins/bearing/references/impeccable.md"

t_begin "SKILL.md has the impeccable pass and its report line"
sk="$(cat "$SK")"
assert_contains "$sk" "### Impeccable pass" "SKILL.md"
assert_contains "$sk" '${CLAUDE_PLUGIN_ROOT}/references/impeccable.md' "SKILL.md"
assert_contains "$sk" "Impeccable: harden <n> and polish <n> screen sets" "output contract"
assert_contains "$sk" "impeccable not installed" "fallback"
assert_contains "$sk" "design-doctrine.md" "doctrine fallback"
assert_contains "$sk" "never by weakening" "gate rule"
assert_contains "$sk" "design-system" "token change routed back"
t_end

t_begin "allowed-tools grants every command the pass runs"
fm="$(sed -n '/^---$/,/^---$/p' "$SK")"
for g in " Skill," "Bash(test:*)" "Bash(printenv BEARING_AUTOPILOT BEARING_NONINTERACTIVE)" \
         "Bash(bash *bin/brg-config get noninteractive --user)" "Bash(sh scripts/design-lint.sh:*)"; do
  assert_contains "$fm" "$g" "allowed-tools"
done
for g in "Bash(mkdir -p .scratch/impeccable-pass/*)" "Bash(cp -p * .scratch/impeccable-pass/*)" "Bash(cp -p .scratch/impeccable-pass/* *)"; do
  assert_contains "$fm" "$g" "snapshot grant"
done
assert_not_contains "$fm" "skills/impeccable/scripts" "unused grant"
t_end

t_begin "the reference section states the unattended polish rule"
sec="$(awk '$0=="## screen-design"{on=1;next} /^## /{on=0} on' "$REF")"
assert_contains "$sec" "harden only" "unattended rule"
assert_contains "$sec" "polish skipped: unattended" "skip line"
assert_contains "$sec" "cp -p .scratch/impeccable-pass/<file> <file>" "revert command"
assert_contains "$sec" "Never \`git checkout\`" "no git revert"
assert_contains "$sec" "polish skipped: unattended (asked)" "asked line"
assert_contains "$sec" "meta.sourceHash" "sync detection"
assert_contains "$sec" "one fix in the" "one fix then revert"
assert_not_contains "$sec" "is reverted and listed; the gate" "old wording"
assert_contains "$sk" "design-lint.sh --sync" "SKILL.md gate list"
assert_contains "$sk" "never git checkout, restore or stash" "SKILL.md revert rule"
assert_not_contains "$sec" "Both run unattended" "old claim"
t_end

t_begin "SKILL.md at or under 200 lines"
lines="$(wc -l < "$SK" | tr -d ' ')"
ok=no; [ "$lines" -le 200 ] && ok=yes; assert_eq yes "$ok" "got $lines"
t_end

t_summary
