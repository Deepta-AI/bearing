#!/usr/bin/env bash
# tests/unit/screen_states.sh: skills/screen-design/scripts/states_check.py
# passes screens that render every state the flows inventory lists and
# fails, with the reason, on a missing panel, a panel without a state-bar
# button, a missing prototype, unfilled placeholders (the raw template),
# and an empty inventory. Without a flows file the baseline five apply,
# less the states the page marks n/a.
set -u
. "$(dirname "$0")/../lib/assert.sh"
CHK="$KIT/skills/screen-design/scripts/states_check.py"

# screen <file> <state>...: a prototype shaped like templates/screen.html.
screen() {
  f="$1"; shift
  { echo '<nav>'; for s in "$@"; do echo "<button data-state-target=\"$s\">$s</button>"; done; echo '</nav>'
    for s in "$@"; do echo "<section data-state=\"$s\" data-component=\"List\" hidden>copy</section>"; done; } > "$f"
}
flows() {
  cat > "$1" <<'MD'
## 1. Screen inventory

| Id | Screen |
| --- | --- |
| S-01 | Orders |

## 2. Interaction states

### S-01 Orders

| State | The user sees | Copy |
| --- | --- | --- |
| loading | skeleton | "Orders" |
| empty | invitation | "No orders yet" |
| error | banner | "Could not load. Retry." |
| success | list | "Saved" |
| partial | some rows | "12 of 40 shown" |
| offline | n/a: web only | |
| `refunded` | a badge | "Refunded" |

### S-02 Order detail

| State | The user sees | Copy |
| --- | --- | --- |
| loading | skeleton | "Order" |
| success | the order | "Order 42" |

## 3. Journey storyboard
MD
}

t_begin "every inventory state rendered passes, n/a rows excluded"
d="$(tmpdir)"; flows "$d/flows.md"
screen "$d/S-01-orders.html" loading empty error success partial refunded
screen "$d/S-02-order-detail.html" loading success
assert_exit 0 python3 "$CHK" --screens "$d" --flows "$d/flows.md"
assert_contains "$T_OUT" "screen-states: 2 screens from $d/flows.md, 8 state panels, 2 of 2 screens with all inventory states, 0 problems"
t_end

t_begin "a missing panel, an unreachable panel and a missing prototype fail"
d="$(tmpdir)"; flows "$d/flows.md"
screen "$d/S-01-orders.html" loading empty error success partial
printf '<section data-state="refunded">x</section>\n' >> "$d/S-01-orders.html"
assert_exit 1 python3 "$CHK" --screens "$d" --flows "$d/flows.md"
assert_contains "$T_OUT" "panel refunded has no state-bar button"
assert_contains "$T_OUT" "S-02: no prototype in"
screen "$d/S-01-orders.html" loading empty error success
assert_exit 1 python3 "$CHK" --screens "$d" --flows "$d/flows.md" --only S-01
assert_contains "$T_OUT" "S-01 (S-01-orders.html): no data-state=\"partial\" panel"
assert_contains "$T_OUT" "no data-state=\"refunded\" panel"
assert_contains "$T_OUT" "0 of 1 screens with all inventory states"
t_end

t_begin "the raw template fails on its placeholders"
d="$(tmpdir)"; cp "$KIT/skills/screen-design/templates/screen.html" "$d/S-01-raw.html"
assert_exit 1 python3 "$CHK" --screens "$d"
assert_contains "$T_OUT" "unfilled placeholders"
t_end

t_begin "without flows the baseline five apply, less the n/a states"
d="$(tmpdir)"
screen "$d/S-01-a.html" loading empty error success
assert_exit 1 python3 "$CHK" --screens "$d"
assert_contains "$T_OUT" "no data-state=\"partial\" panel"
printf '<!-- n/a: partial because the list is never paged -->\n' >> "$d/S-01-a.html"
assert_exit 0 python3 "$CHK" --screens "$d"
assert_contains "$T_OUT" "baseline five (no flows file)"
t_end

t_begin "an empty inventory fails"
d="$(tmpdir)"
assert_exit 1 python3 "$CHK" --screens "$d"
assert_contains "$T_OUT" "0 screens in the inventory"
printf '## 2. Interaction states\n\n## 3. Next\n' > "$d/flows.md"
assert_exit 1 python3 "$CHK" --screens "$d" --flows "$d/flows.md"
assert_contains "$T_OUT" "nothing checked"
t_end

t_summary
