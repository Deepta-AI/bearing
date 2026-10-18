#!/usr/bin/env bash
# tests/unit/flow_order.sh: screens come before the contract in the flows.
set -u
. "$(dirname "$0")/../lib/assert.sh"
# pos <flow> <skill>: its order number in flow-steps.tsv
pos() { awk -F'\t' -v f="$1" -v s="$2" '$1==f && $3==s {print $2; exit}' "$KIT/plugins/bearing/bin/flow-steps.tsv"; }
before() { _t_count; [ -n "$(pos "$1" "$2")" ] && [ -n "$(pos "$1" "$3")" ] && [ "$(pos "$1" "$2")" -lt "$(pos "$1" "$3")" ] || _t_fail "$1: $2 is not before $3"; }
t_begin "greenfield: high-level design, then the screens, then the contract, then the low-level design"
before greenfield high-level-design ux-flows
before greenfield ux-flows design-directions; before greenfield design-directions design-system
before greenfield design-system screen-design; before greenfield screen-design data-model
before greenfield data-model openapi-spec; before greenfield openapi-spec threat-model
before greenfield threat-model low-level-design
t_end
t_begin "feature: screens come before the API and the data model"
before feature ux-flows openapi-spec; before feature screen-design data-model
t_end
t_begin "genai: the golden set comes before dataset-generation, which checks against it (I4)"
before genai llm-eval dataset-generation
t="$(tr '\n' ' ' < "$KIT/plugins/bearing-genai/skills/dataset-generation/SKILL.md" | tr -s ' ')"
assert_contains "$t" "No \`evals/<name>/cases.jsonl\` yet: kind \`eval\` leaves \`--against\` out"
assert_contains "$t" "\`train\` and \`preference\` stop with"
t_end
t_summary
