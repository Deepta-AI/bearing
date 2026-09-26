#!/usr/bin/env bash
# tests/unit/screen_bundle.sh: skills/screen-design/scripts/bundle.py
# audits a design bundle from the files and writes real numbers into
# design.json, renders the gallery, and checks it: passes a complete bundle
# and fails, with the reason, on a null audit, a stale audit, a state panel
# without its app chrome or its annotation, a link to a screen file that does
# not exist, a navigation-map edge with no link, a colour literal, a screen
# that does not link tokens.css, a story nothing serves, a flows screen the
# manifest lacks, and a manifest with zero screens.
set -u
. "$(dirname "$0")/../lib/assert.sh"
B="$KIT/skills/screen-design/scripts/bundle.py"

# panel <state> <desktop chrome> <annotation>: one state drawn as the whole screen.
panel() {
  printf '<section data-state="%s"><div class="annotation"><p data-annotation>%s</p></div>\n' "$1" "$3"
  printf '<div data-frame="desktop"><div class="app" data-app-chrome="%s"><nav><a href="S-01-orders.html">Orders</a></nav><p>x</p></div></div>\n' "$2"
  printf '<div data-frame="mobile"><div class="phone" data-app-chrome="bottom-tab-bar"><nav><a href="S-01-orders.html">Orders</a></nav></div></div></section>\n'
}
# screen <file> <link target> <state>...: a prototype shaped like templates/screen.html.
screen() {
  f="$1"; to="$2"; shift 2
  { echo '<!doctype html><html><head><link rel="stylesheet" href="../../tokens.css">'
    echo '<style>.a { color: var(--color-text); }</style></head><body>'
    echo "<a href=\"$to\">Next</a>"
    for s in "$@"; do panel "$s" side-nav "The $s state shows what changed from the default and why."; done
    echo '</body></html>'; } > "$f"
}
bundle() {
  d="$1"; mkdir -p "$d/screens/orders" "$d/flows/orders"
  printf ':root { --color-text: #111111; }\n' > "$d/tokens.css"
  printf '# Sync\n' > "$d/DESIGN-SYNC.md"
  cat > "$d/flows/orders/flows.md" <<'MD'
## 1. Screen inventory

| Id | Screen | Purpose | Serves | Entry from | Exits to | Status |
| --- | --- | --- | --- | --- | --- | --- |
| S-01 | Orders | See orders | US-01-001 | nav | S-02 | new |
| S-02 | Order detail | One order | US-01-002 | S-01 | S-01 | new |

## 4. Navigation map

```mermaid
flowchart LR
  S01[S-01 Orders] --> S02[S-02 Order detail]
  S02 -->|back| S01
```
MD
  screen "$d/screens/orders/S-01-orders.html" S-02-order-detail.html success loading
  screen "$d/screens/orders/S-02-order-detail.html" S-01-orders.html success error
  cat > "$d/design.json" <<'JSON'
{
  "product": "Ledgerline", "version": 1,
  "brief": {"surface": "web app", "audience": "Clerks who reconcile orders", "must_feel": "calm", "avoid": "gradients"},
  "directions": [{"name": "Plain ledger", "rationale": "Reads like a statement.", "chosen": true}],
  "sitemap": [{"name": "Orders", "children": [{"name": "Orders", "screen": "orders/S-01"}, {"name": "Order detail", "screen": "orders/S-02"}]}],
  "navigation": {"desktop": "Side nav", "mobile": "Bottom tab bar", "why": "Two levels deep"},
  "screens": [
    {"key": "orders/S-01", "name": "Orders", "purpose": "See orders", "platform": "both", "serves": ["US-01-001"], "states": ["success", "loading"], "path": "screens/orders/S-01-orders.html"},
    {"key": "orders/S-02", "name": "Order detail", "purpose": "One order", "platform": "both", "serves": ["US-01-002"], "states": ["success", "error"], "path": "screens/orders/S-02-order-detail.html"}
  ],
  "concerns": [{"kind": "risk", "detail": "Refunds are out of scope.", "screen": "orders/S-02"}],
  "audit": null
}
JSON
}

t_begin "a complete bundle: audit writes real numbers, gallery renders, check passes"
d="$(tmpdir)"; bundle "$d"
assert_exit 1 python3 "$B" check --design "$d"
assert_contains "$T_OUT" "design.json audit is null: the audit never ran"
assert_contains "$T_OUT" "no index.html gallery"
assert_exit 0 python3 "$B" audit --design "$d"
assert_contains "$T_OUT" "design-bundle audit: 2 screens (1 features), 4 state panels"
assert_contains "$T_OUT" "1 flows files, 2 stories, 0 audit findings"
assert_contains "$(cat "$d/design.json")" '"missing_chrome": []'
assert_contains "$(cat "$d/design.json")" '"panels": 4'
assert_exit 0 python3 "$B" gallery --design "$d"
assert_contains "$T_OUT" "design-bundle gallery: 2 screens rendered, 1 concerns"
assert_contains "$(cat "$d/index.html")" 'href="screens/orders/S-02-order-detail.html#state=error"'
assert_contains "$(cat "$d/index.html")" "Raised while designing"
assert_not_contains "$(cat "$d/index.html")" "{{"
assert_exit 0 python3 "$B" check --design "$d"
assert_contains "$T_OUT" "design-bundle check: 2 screens (1 features), 4 state panels"
assert_contains "$T_OUT" "0 audit findings"
assert_contains "$T_OUT" ", 0 problems"
t_end

t_begin "missing chrome, a missing annotation and a missing mobile frame fail, and a stale audit is caught"
d="$(tmpdir)"; bundle "$d"
python3 "$B" audit --design "$d" >/dev/null; python3 "$B" gallery --design "$d" >/dev/null
sed -i.bak 's/data-app-chrome="side-nav"/data-app-chrome=""/; s#<p data-annotation>The loading state shows what changed from the default and why.</p>#<p data-annotation>tbd</p>#' "$d/screens/orders/S-01-orders.html"
assert_exit 1 python3 "$B" check --design "$d"
assert_contains "$T_OUT" "orders/S-01: state success, desktop frame has no data-app-chrome slot"
assert_contains "$T_OUT" "orders/S-01: state loading has no data-annotation saying what changed and why"
assert_contains "$T_OUT" "audit.missing_chrome is stale: recorded 0, the files give 2"
sed -i.bak 's#<div data-frame="mobile">.*</section>#</section>#' "$d/screens/orders/S-02-order-detail.html"
assert_exit 1 python3 "$B" audit --design "$d"
assert_contains "$T_OUT" 'orders/S-02: state error has no data-frame="mobile"'
assert_contains "$(cat "$d/design.json")" 'has no data-frame=\"mobile\"'
t_end

t_begin "a dead link, a missing navigation-map link, a colour literal and an unlinked token file fail"
d="$(tmpdir)"; bundle "$d"
screen "$d/screens/orders/S-01-orders.html" S-01-orders.html success loading
screen "$d/screens/orders/S-02-order-detail.html" S-09-refunds.html success error
printf '<p style="color: #ff0000">x</p><link rel="stylesheet" href="https://cdn.example.org/x.css">\n' >> "$d/screens/orders/S-02-order-detail.html"
sed -i.bak 's#../../tokens.css#../tokens.css#' "$d/screens/orders/S-01-orders.html"
assert_exit 1 python3 "$B" audit --design "$d"
assert_contains "$T_OUT" "screens/orders/S-02-order-detail.html: S-09-refunds.html points at no file"
assert_contains "$T_OUT" "orders/S-01 -> orders/S-02: the navigation map has this edge, S-01-orders.html has no link to S-02-order-detail.html"
assert_contains "$T_OUT" "hardcoded_colours: orders/S-02: 1 (first #ff0000)"
assert_contains "$T_OUT" "external_refs: screens/orders/S-02-order-detail.html: https://cdn.example.org/x.css"
assert_contains "$T_OUT" "unlinked_tokens: orders/S-01: links no tokens.css and carries none inline"
t_end

t_begin "an uncovered story, a flows screen missing from the manifest and a missing state fail"
d="$(tmpdir)"; bundle "$d"
printf '| S-03 | Refund | Refund an order | US-01-003 | S-02 | S-01 | new |\n' > "$d/row"
sed -i.bak "/^| S-02 /r $d/row" "$d/flows/orders/flows.md"
python3 - "$d/design.json" <<'PY'
import json, sys
m = json.load(open(sys.argv[1])); m["screens"][0]["states"].append("empty")
json.dump(m, open(sys.argv[1], "w"))
PY
assert_exit 1 python3 "$B" audit --design "$d"
assert_contains "$T_OUT" "missing_screens: orders/S-03: in flows/orders/flows.md, not in design.json"
assert_contains "$T_OUT" "uncovered_stories: US-01-003: no screen serves it and no concern names it"
assert_contains "$T_OUT" 'missing_states: orders/S-01: no data-state="empty" panel'
t_end

t_begin "zero screens and a broken manifest fail"
d="$(tmpdir)"; bundle "$d"
python3 - "$d/design.json" <<'PY'
import json, sys
m = json.load(open(sys.argv[1])); m["screens"] = []; m["concerns"] = [{"kind": "worry", "detail": "x"}]
json.dump(m, open(sys.argv[1], "w"))
PY
assert_exit 1 python3 "$B" audit --design "$d"
assert_contains "$T_OUT" "0 screens in design.json, nothing checked"
assert_contains "$T_OUT" "design.json.screens: needs at least 1 items"
assert_contains "$T_OUT" "'worry' is not one of ambiguity"
assert_exit 1 python3 "$B" gallery --design "$d"
assert_contains "$T_OUT" "0 screens rendered"
e="$(tmpdir)"
assert_exit 1 python3 "$B" check --design "$e"
assert_contains "$T_OUT" "cannot read"
t_end

t_begin "the raw screen template carries both frames and a chrome slot on every panel; its unfilled annotations fail"
d="$(tmpdir)"; bundle "$d"
cp "$KIT/skills/screen-design/templates/screen.html" "$d/screens/orders/S-01-orders.html"
python3 - "$d/design.json" <<'PY'
import json, sys
m = json.load(open(sys.argv[1])); m["screens"][0]["states"] = ["success", "loading", "empty", "error", "partial"]
json.dump(m, open(sys.argv[1], "w"))
PY
assert_exit 1 python3 "$B" audit --design "$d"
assert_not_contains "$T_OUT" "orders/S-01: state success, desktop frame"
assert_not_contains "$T_OUT" "orders/S-01: state loading has no data-frame"
assert_contains "$T_OUT" "orders/S-01: state loading has no data-annotation"
assert_not_contains "$T_OUT" "missing_states: orders/S-01"
assert_not_contains "$T_OUT" "unlinked_tokens: orders/S-01"
assert_not_contains "$T_OUT" "hardcoded_colours: orders/S-01"
t_end

t_summary
