#!/usr/bin/env bash
# tests/unit/ux_flows_check.sh: plugins/bearing/skills/ux-flows/scripts/flows_check.py
# passes a package whose screens all have a way forward (or are marked
# terminal), all appear in a flowchart and all have the four required
# states; fails on a dead end, an unflowed screen, a flowchart screen not
# in the inventory, a missing state, n/a without a reason, a screen with no
# state table, a dialog with no way back, and on empty input. It reads
# the highest flows-v<n>.md and skips screens marked removed.
set -u
. "$(dirname "$0")/../lib/assert.sh"
CHK="$KIT/plugins/bearing/skills/ux-flows/scripts/flows_check.py"

# states <id>: a complete state table for one screen.
states() {
  printf '### %s screen\n\n| State | The user sees | Copy |\n| --- | --- | --- |\n' "$1"
  printf '| loading | skeleton | "Loading orders" |\n| empty | one invitation | "No orders yet" |\n'
  printf '| error | message above the list | "We could not load orders. Retry." |\n| success | the list | "Saved" |\n'
  printf '| offline | n/a: the screen does not write data | |\n\n'
}
# fixture <file>: three screens, S-03 terminal, a nav map and a happy path.
fixture() {
  mkdir -p "$(dirname "$1")"
  {
    printf '# UX flows: orders (v1)\n\n## 1. Screen inventory\n\n'
    printf '| Id | Screen | Purpose | Serves | Entry from | Exits to | Status |\n| --- | --- | --- | --- | --- | --- | --- |\n'
    printf '| S-01 | Orders | list | US-01-001 | nav | S-02 | new |\n'
    printf '| S-02 (modal) | Confirm | confirm | US-01-001 | S-01 | cancel, confirm | new |\n'
    printf '| S-03 | Done | receipt | US-01-001 | S-02 | terminal: the flow ends here | new |\n\n'
    printf '## 2. Interaction states\n\n'
    states S-01; states S-02; states S-03
    printf '## 4. Navigation map\n\n```mermaid\nflowchart LR\n  S01[S-01 Orders] --> S02[S-02 Confirm]\n  S02 -->|cancel| S01\n```\n\n'
    printf '## 5. Flows\n\n```mermaid\nflowchart TD\n  A[S-01 pick] --> B{valid?}\n  B -->|yes| C[S-03 done]\n  B -- no --> A\n```\n\n'
    printf '```mermaid\nsequenceDiagram\n  U->>S: tap\n```\n'
  } > "$1"
}
run() { (cd "$1" && python3 "$CHK"); }

t_begin "a complete package passes with its counts"
d="$(tmpdir)/ok"; fixture "$d/docs/design/flows/orders/flows.md"
assert_exit 0 run "$d"
assert_contains "$T_OUT" "Dead ends: 0"
assert_contains "$T_OUT" "ux-flows: 1 files, 3 screens (1 terminal, 0 removed), 1 dialogs (0 without a way back), 2 flowcharts, 5 edges, 0 dead ends, 0 unflowed, 3 state tables, 0 missing states, 0 problems"
t_end

t_begin "a dead end, an unflowed screen and an unknown screen fail"
d="$(tmpdir)/dead"; f="$d/docs/design/flows/orders/flows.md"; fixture "$f"
sed -i.bak 's/| terminal: the flow ends here |/| none |/' "$f"
sed -i.bak 's/^| S-03 | Done .*$/&\n| S-04 | Help | help | US-01-001 | S-01 | back | new |/' "$f"
printf '```mermaid\nflowchart LR\n  S09[S-09 Stray] --> S01\n```\n' >> "$f"
states S-04 >> "$f"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "S-03 is a dead end (no outgoing edge"
assert_contains "$T_OUT" "S-04 is in the inventory but in no flowchart"
assert_contains "$T_OUT" "S-09 is in a flowchart but not in the screen inventory"
assert_contains "$T_OUT" "Dead ends: 2"
t_end

t_begin "a %% terminal marker in a flowchart also ends a flow"
d="$(tmpdir)/marker"; f="$d/docs/design/flows/orders/flows.md"; fixture "$f"
sed -i.bak 's/| terminal: the flow ends here |/| none |/; s/^flowchart TD$/flowchart TD\n  %% terminal: S-03 the receipt is the end/' "$f"
assert_exit 0 run "$d"
assert_contains "$T_OUT" "3 screens (1 terminal, 0 removed)"
t_end

t_begin "missing, blank and reasonless n/a states fail; so does no state table"
d="$(tmpdir)/states"; f="$d/docs/design/flows/orders/flows.md"; fixture "$f"
python3 - "$f" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
a, b = s.split("### S-02", 1)
b = b.replace('| empty | one invitation | "No orders yet" |\n', '', 1)
b = b.replace('| error | message above the list | "We could not load orders. Retry." |', '| error | n/a | |', 1)
b = b.replace('| success | the list | "Saved" |', '| success |  |  |', 1)
s = a + "### S-02" + b
c, e = s.split("### S-03 screen", 1)
s = c + "#### S-03 notes" + e
open(p, "w").write(s)
PY
assert_exit 1 run "$d"
assert_contains "$T_OUT" "S-02 state 'empty' is missing or blank"
assert_contains "$T_OUT" "S-02 state 'error' is n/a without a reason"
assert_contains "$T_OUT" "S-02 state 'success' is missing or blank"
assert_contains "$T_OUT" "S-03 has no state table"
t_end

t_begin "a dialog with no cancel, back or close in Exits fails"
d="$(tmpdir)/dialog"; f="$d/docs/design/flows/orders/flows.md"; fixture "$f"
sed -i.bak 's/| cancel, confirm |/| confirm to S-03 |/' "$f"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "S-02 is a dialog with no cancel, back or close in its Exits"
assert_contains "$T_OUT" "1 dialogs (1 without a way back)"
t_end

t_begin "a removed screen is skipped; a combined state row fills each state; a Screens heading is read"
d="$(tmpdir)/removed"; f="$d/docs/design/flows/orders/flows-v2.md"; fixture "$f"
sed -i.bak 's/^| S-03 | Done .*$/&\n| S-04 | Old step | gone | US-01-001 | none | none | removed in v2 |/; s/^## 1\. Screen inventory$/## Screens/' "$f"
python3 - "$f" <<'PY2'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace('| loading | skeleton | "Loading orders" |\n| empty | one invitation | "No orders yet" |\n', '| Loading, Empty | n/a: a single action on known data | |\n', 1)
open(p, "w").write(s)
PY2
assert_exit 0 run "$d"
assert_contains "$T_OUT" "3 screens (1 terminal, 1 removed)"
t_end

t_begin "the highest version is the one checked"
d="$(tmpdir)/ver"; fixture "$d/docs/design/flows/orders/flows.md"
fixture "$d/docs/design/flows/orders/flows-v2.md"
sed -i.bak '/S02 -->|cancel| S01/d; /B -- no --> A/d; s/B -->|yes| C\[S-03 done\]/B -->|yes| C[S-03 done]\n  S02 --> A/' "$d/docs/design/flows/orders/flows-v2.md"
printf 'broken\n' > "$d/docs/design/flows/orders/flows.md"
assert_exit 0 run "$d"
assert_contains "$T_OUT" "ux-flows: 1 files, 3 screens"
t_end

t_begin "empty input fails: no flow file, or no screens"
d="$(tmpdir)/empty"; mkdir -p "$d"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "0 flow files read"
mkdir -p "$d/docs/design/flows/x"; printf '# UX flows\n\n## 1. Screen inventory\n\n' > "$d/docs/design/flows/x/flows.md"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "0 screens in the inventory, nothing checked"
t_end

t_summary
