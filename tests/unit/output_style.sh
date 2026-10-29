#!/usr/bin/env bash
# tests/unit/output_style.sh: the Bearing report output style is the
# repository template's default, under the name Claude Code lists it by
# ("bearing:" + the style's frontmatter name). A plain name matches no style
# and is ignored without a warning, so a rename on one side must fail here.
set -u
. "$(dirname "$0")/../lib/assert.sh"
STYLE="$KIT/plugins/bearing/output-styles/bearing-report.md"
TPL="$KIT/plugins/bearing/templates/repo/.claude/settings.json"

t_begin "the template names the style as Claude Code lists it"
name="$(sed -n 's/^name: *//p' "$STYLE" | head -1)"
assert_eq "Bearing report" "$name" "frontmatter name"
assert_eq "bearing:$name" "$(jq -r '.outputStyle' "$TPL")" "template outputStyle"
assert_contains "$(cat "$KIT/docs/INSTALL.md")" "\"outputStyle\": \"bearing:$name\"" "INSTALL gives the same value"
t_end

t_begin "the style keeps the report headings and the answer-first rule"
s="$(cat "$STYLE")"
for h in "**Changed**" "**Verified**" "**Not done**" "**Noticed**" "**Answer first.**" "**A table when items share attributes.**"; do
  assert_contains "$s" "$h" "$h"
done
assert_contains "$s" "keep-coding-instructions: true"
t_end

t_summary
