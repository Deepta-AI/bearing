#!/usr/bin/env bash
# tests/unit/autopilot_stages.sh: the stages brg-autopilot gained after the
# first real run skipped every skill no gate checked. The decide gate
# needs a product profile (ui, data, api, deploy). architecture needs a C4
# file with a diagram and an architecture.json whose SVGs pass
# diagram_check. design adds, by profile, the data model, the API contract
# and a deployment architecture with its diagram, after arch_check
# and (profile data) model_check pass. ux runs the flows, contrast,
# screen-state and design-bundle checkers for a UI. test_cases runs cases_check.
# test_automation needs every automatable TC id named by a test. design_review
# needs a review for a UI. dod refuses a profile the code contradicts.
set -u
. "$(dirname "$0")/../lib/assert.sh"
AP="$KIT/plugins/bearing/bin/brg-autopilot"
ap() { python3 "$AP" "$@" --dir "$d"; }
commit() { git -C "$d" add -A >/dev/null 2>&1; git -C "$d" -c user.email=t@e -c user.name=t commit -qm "$1" >/dev/null 2>&1; }

# at <stage>: a fresh repository whose run has every stage before <stage> done.
at() {
  d="$(tmpdir)/run"
  git init -q -b main "$d"
  printf 'check:\n\t@mkdir -p .bearing/state && touch .bearing/state/.check-passed\n' > "$d/Makefile"
  printf '.bearing/state/\n.scratch/\n' > "$d/.gitignore"; commit init
  mkdir -p "$d/.bearing/state"
  python3 - "$d/.bearing/state/autopilot.json" "$1" "$(python3 "$AP" stages)" <<'PY'
import json, sys, time
path, stop, names = sys.argv[1], sys.argv[2], sys.argv[3].split()
st = {"run": "r", "statement": "s", "started": "t", "started_epoch": time.time(), "decisions": [],
      "stages": {n: {"status": "done" if names.index(n) < names.index(stop) else "pending",
                     "attempts": 0, "checked": "", "notes": []} for n in names}}
json.dump(st, open(path, "w"))
PY
}
# profile <ui> <data> <api> <deploy> [ui stack]: the stack defaults to react-shadcn.
profile() { ap profile --ui "$1" --data "$2" --api "$3" --deploy "$4" ${5:+--ui-stack "$5"} --why "fixture" >/dev/null; }
mermaid() { printf '# %s\n\n```mermaid\nflowchart LR\n  A --> B\n```\n' "$2" > "$1"; }
ARCH_MODEL="$KIT/tests/fixtures/architecture/architecture.json"

# design fixtures: the shapes the checker tests pass (hld_arch_check, data_model_check).
risks() { printf '\n**Risks this leaves open**\n\n- %s\n' "$1"; }
# archset <repo>: a passing HLD (x-hld.md), tenets, decisions index, ADRs and repo plan.
archset() {
  local r="$1" i
  mkdir -p "$r/docs/design" "$r/docs/architecture" "$r/docs/adr"
  printf '# ADR-0001: Use Postgres\n' > "$r/docs/adr/0001-use-postgres.md"
  { printf '# High Level Design: orders\n\n- Status: Draft\n\n## Summary\n\nOne service, one Postgres.\n\n'
    printf 'Diagram: docs/architecture/diagrams/Shop_SystemArchitecture_v1.svg\n\n## What gets built\n\n'
    printf '| Component | Kind | Stack | Responsibility | Repository |\n| --- | --- | --- | --- | --- |\n'
    printf '| Api | backend | Go | orders | ShopApi |\n\n'
    printf '## 1. Goal and non-goals\n\nGoal.\n\n## 3. Architecture\n\nText.\n'; risks "one process"
    printf '\n## 4. Data\n\nText.\n'; risks "no purge"
    printf '\n## 6. External integrations\n\nPayments.\n\n### Deliberately not integrated\n\n- No analytics SDK: privacy.\n'; risks "provider outage"
    printf '\n## 8. Scaling and limits\n\n120/min.\n'; risks "untested"
    printf '\n## 9. Security and privacy\n\nText.\n'; risks "token theft"
    printf '\n## 10. Observability\n\nText.\n'; risks "no aggregator"
    printf '\n## 11. Analytics\n\nText.\n'; risks "lower bound"
    printf '\n## 12. Rollout and rollback\n\nText.\n'; risks "manual rollback"
    printf '\n## 13. Outside the standard stack\n\nNone: every technology is a catalogue default.\n'
    printf '\n## 14. Repository plan\n\nSee repo-plan.json.\n'
    printf '\n## 16. What the review found\n\nReviewed by: critic, 2026-09-25\n\n'
    printf '### MINOR: endpoint named two ways\n\nADR-0001 and section 11 disagree.\nConflicts with: ADR-0001, section 11\nFix: use ADR-0001 names.\nStatus: fixed (section 11)\n'
  } > "$r/docs/design/x-hld.md"
  { printf '# System design tenets: Shop\n\n'
    for i in 1 2 3 4 5; do printf '## %s. Tenet %s\n\n**Rule %s holds.**\n\nWhy.\n\n_A breach looks like:_ an MR that breaks it.\n\n' "$i" "$i" "$i"; done
  } > "$r/docs/architecture/tenets.md"
  { printf '# Architecture decisions: Shop\n\n## Decisions\n\n| Id | Title | Area | Status | Reversibility |\n| --- | --- | --- | --- | --- |\n'
    printf '| ADR-0001 | Use Postgres | database | Proposed | irreversible: every table moves |\n\n'
    printf '## Conflicts that were settled\n\nNone found: the HLD, the ADR and the stories were compared.\n'
  } > "$r/docs/architecture/decisions.md"
  printf '{"project": "Shop", "group": "Shop", "repos": [{"name": "ShopApi", "git_path": "Shop/Server/ShopApi", "stack": "go-api", "responsibility": "orders"}]}\n' \
    > "$r/docs/architecture/repo-plan.json"
}
# datamodel <repo>: the data-model templates, which model_check passes as shipped.
datamodel() { cp "$KIT/plugins/bearing/skills/data-model/templates/"{schema.sql,data-dictionary.csv,data-model.md} "$1/docs/design/"; }

t_begin "the stage list runs architecture, ux, test cases and test automation in order"
assert_exit 0 python3 "$AP" stages
assert_eq "repo prd stories decide architecture design ux test_cases branch build test_automation design_review review dod mr" "$(printf '%s' "$T_OUT" | tr '\n' ' ' | sed 's/ $//')" "stage order"
t_end

t_begin "decide needs the product profile, recorded in the digest"
at decide
ap decision none-open - - "fixture" >/dev/null
assert_exit 1 ap "done" decide
assert_contains "$T_OUT" "no product profile"
assert_exit 2 ap profile --ui maybe --data yes --api yes --deploy yes --why x
assert_exit 0 ap profile --ui yes --data no --api yes --deploy yes --why "a web app over an API"
assert_contains "$T_OUT" "profile: ui=yes data=no api=yes deploy=yes"
assert_exit 0 ap "done" decide
assert_exit 0 ap status
assert_contains "$T_OUT" "profile: ui=yes data=no api=yes deploy=yes"
assert_exit 0 ap report
assert_contains "$(cat "$d/docs/autopilot/r.md")" "| profile | ui=yes data=no api=yes deploy=yes ui_stack=react-shadcn scope=full |"
t_end

t_begin "architecture needs a C4 file with at least one diagram"
at architecture; profile yes yes yes yes
assert_exit 1 ap "done" architecture
assert_contains "$T_OUT" "no docs/architecture/*-c4.md (architecture-diagram)"
mkdir -p "$d/docs/architecture"; printf '# C4\nprose only\n' > "$d/docs/architecture/system-c4.md"
assert_exit 1 ap "done" architecture
assert_contains "$T_OUT" "0 mermaid diagrams"
mermaid "$d/docs/architecture/system-c4.md" "C4"
assert_exit 1 ap "done" architecture
assert_contains "$T_OUT" "no docs/architecture/architecture.json (architecture-diagram step 9)"
cp "$ARCH_MODEL" "$d/docs/architecture/architecture.json"
assert_exit 1 ap "done" architecture
assert_contains "$T_OUT" "diagram_check failed"
assert_contains "$T_OUT" "0 SVG files"
python3 "$KIT/plugins/bearing/skills/architecture-diagram/scripts/render.py" --model "$d/docs/architecture/architecture.json" \
  --out "$d/docs/architecture/diagrams" --no-png >/dev/null
assert_exit 0 ap "done" architecture
assert_contains "$T_OUT" "1 C4 file(s), 1 mermaid diagram(s); diagram-check: 3 diagrams, 26 nodes, 27 connections"
assert_contains "$T_OUT" " 0 problems"
t_end

t_begin "design requires the data model, API contract and deployment the profile names"
at design; profile yes yes yes yes
mkdir -p "$d/docs/design" "$d/docs/architecture" "$d/api"
printf '# HLD\n' > "$d/docs/design/x-hld.md"; printf '# LLD\n' > "$d/docs/design/x-lld.md"
assert_exit 1 ap "done" design
assert_contains "$T_OUT" "docs/design/data-model.md (data-model)"
assert_contains "$T_OUT" "api/openapi.yaml (openapi-spec)"
assert_contains "$T_OUT" "docs/architecture/deployment.md (deployment-architecture)"
printf '# Data model\n' > "$d/docs/design/data-model.md"; printf 'openapi: 3.1.0\n' > "$d/api/openapi.yaml"
printf '# Deployment\nno picture\n' > "$d/docs/architecture/deployment.md"
assert_exit 1 ap "done" design
assert_contains "$T_OUT" "arch_check failed"
assert_contains "$T_OUT" "Gate: FAILED"
archset "$d"
assert_exit 1 ap "done" design
assert_contains "$T_OUT" "model_check failed"
datamodel "$d"
assert_exit 1 ap "done" design
assert_contains "$T_OUT" "docs/architecture/deployment.md has no mermaid diagram"
mermaid "$d/docs/architecture/deployment.md" "Deployment"
assert_exit 0 ap "done" design
assert_contains "$T_OUT" "HLD 1, LLD 1, data model, API contract, deployment with 1 diagram(s)"
t_end

t_begin "a full-scope profile without data, API or deployment needs only the HLD and LLD"
at design; ap profile --ui no --data no --api no --deploy no --scope full --why fixture >/dev/null
archset "$d"; printf '# LLD\n' > "$d/docs/design/x-lld.md"
assert_exit 0 ap "done" design
assert_contains "$T_OUT" "HLD 1, LLD 1; profile: data=no api=no deploy=no"
t_end

t_begin "lean scope: a change to an existing repository, or a product with nothing but code, owes one design note"
at architecture; profile no no no no
assert_exit 0 ap "done" architecture
assert_contains "$T_OUT" "scope lean (no ui, data, api or deploy): no C4 set"
assert_exit 1 ap "done" design
assert_contains "$T_OUT" "no design note written this run"
mkdir -p "$d/docs/design"; printf '# Search\nshort\n' > "$d/docs/design/search.md"
assert_exit 1 ap "done" design
python3 -c "print('# Search\n\n' + 'The search command reads the store through notes() and prints matches. ' * 4)" > "$d/docs/design/search.md"
assert_exit 0 ap "done" design
assert_contains "$T_OUT" "design note docs/design/search.md"
# an existing repository is lean whatever the profile says, unless the profile says full
at architecture; python3 - "$d/.bearing/state/autopilot.json" <<'PY2'
import json, sys
st = json.load(open(sys.argv[1])); st["existing"] = True; json.dump(st, open(sys.argv[1], "w"))
PY2
profile yes yes yes yes
assert_exit 0 ap "done" architecture
assert_contains "$T_OUT" "a change to an existing repository"
at architecture; ap profile --ui no --data no --api no --deploy no --scope full --why x >/dev/null
assert_exit 1 ap "done" architecture
assert_contains "$T_OUT" "no docs/architecture/*-c4.md"
t_end

t_begin "start marks a repository that already had code as existing, and an empty one as not"
d="$(tmpdir)/fresh"; mkdir -p "$d"
assert_exit 0 ap start "a word counter"
assert_eq "False" "$(python3 -c "import json;print(json.load(open('$d/.bearing/state/autopilot.json'))['existing'])")" "empty directory"
d="$(tmpdir)/old"; git init -q -b main "$d"; printf 'x = 1\n' > "$d/app.py"; commit init
assert_exit 0 ap start "add a flag"
assert_eq "True" "$(python3 -c "import json;print(json.load(open('$d/.bearing/state/autopilot.json'))['existing'])")" "repository with code"
t_end

# ux fixtures: the shapes the checker tests pass (ux_flows_check, design_contrast, screen_states).
states() {
  printf '### %s screen\n\n| State | The user sees | Copy |\n| --- | --- | --- |\n' "$1"
  printf '| loading | skeleton | "Loading orders" |\n| empty | one invitation | "No orders yet" |\n'
  printf '| error | message above the list | "We could not load orders. Retry." |\n| success | the list | "Saved" |\n'
  printf '| offline | n/a: the screen does not write data | |\n\n'
}
flows() {
  mkdir -p "$(dirname "$1")"
  { printf '# UX flows: orders (v1)\n\n## 1. Screen inventory\n\n'
    printf '| Id | Screen | Purpose | Serves | Entry from | Exits to | Status |\n| --- | --- | --- | --- | --- | --- | --- |\n'
    printf '| S-01 | Orders | list | US-01-001 | nav | S-02 | new |\n'
    printf '| S-02 | Done | receipt | US-01-001 | S-01 | terminal: the flow ends here | new |\n\n'
    printf '## 2. Interaction states\n\n'; states S-01; states S-02
    printf '## 4. Navigation map\n\n```mermaid\nflowchart LR\n  S01[S-01 Orders] --> S02[S-02 Done]\n```\n'
  } > "$1"
}
tokens() {
  python3 - "$1" "${2:-}" <<'PY'
import json, sys
back = ["bg", "bg-subtle", "surface", "surface-raised", "overlay", "accent-subtle",
        "success-subtle", "warning-subtle", "danger-subtle", "info-subtle", "selection",
        "on-accent", "on-success", "on-warning", "on-danger", "on-info"]
fore = ["text", "text-muted", "text-disabled", "link", "border", "border-strong", "accent",
        "accent-hover", "accent-active", "success", "warning", "danger", "info", "focus"]
def mode(light):
    b, f = ("oklch(0.98 0 0)", "oklch(0.25 0 0)") if light else ("oklch(0.2 0 0)", "oklch(0.95 0 0)")
    return {**{r: b for r in back}, **{r: f for r in fore}}
t = {"meta": {"name": "x", "version": 1, "source": "brief"},
     "color": {"primitives": {}, "roles": {"light": mode(True), "dark": mode(False)}}}
if sys.argv[2]:
    k, v = sys.argv[2].split("=", 1); t["color"]["roles"]["light"][k] = v
json.dump(t, open(sys.argv[1], "w"))
PY
}
# screen <file> <link target> <state>...: a state bar for states_check, and per state a
# panel shaped like the screen_bundle fixture (annotation, desktop and mobile frames, chrome).
screen() {
  f="$1"; to="$2"; shift 2; mkdir -p "$(dirname "$f")"
  { echo '<!doctype html><html><head><link rel="stylesheet" href="../../tokens.css"></head><body>'
    echo '<nav>'; for s in "$@"; do echo "<button data-state-target=\"$s\">$s</button>"; done; echo '</nav>'
    [ -n "$to" ] && echo "<a href=\"$to\">Next</a>"
    for s in "$@"; do
      printf '<section data-state="%s" data-component="List" hidden><div class="annotation"><p data-annotation>The %s state shows what changed from the default and why.</p></div>\n' "$s" "$s"
      printf '<div data-frame="desktop"><div class="app" data-app-chrome="side-nav"><p>copy</p></div></div>\n'
      printf '<div data-frame="mobile"><div class="phone" data-app-chrome="bottom-tab-bar"><p>copy</p></div></div></section>\n'
    done; echo '</body></html>'; } > "$f"
}
# manifest <design dir>: tokens.css, DESIGN-SYNC.md and a design.json listing the two screens.
manifest() {
  printf ':root { --color-text: #111111; }\n' > "$1/tokens.css"; printf '# Sync\n' > "$1/DESIGN-SYNC.md"
  cat > "$1/design.json" <<'JSON'
{
  "product": "Orders", "version": 1,
  "brief": {"surface": "web app", "audience": "Clerks who reconcile orders", "must_feel": "calm", "avoid": "gradients"},
  "directions": [{"name": "Plain ledger", "rationale": "Reads like a statement.", "chosen": true}],
  "sitemap": [{"name": "Orders", "children": [{"name": "Orders", "screen": "orders/S-01"}, {"name": "Done", "screen": "orders/S-02"}]}],
  "navigation": {"desktop": "Side nav", "mobile": "Bottom tab bar", "why": "Two levels deep"},
  "screens": [
    {"key": "orders/S-01", "name": "Orders", "purpose": "list", "platform": "both", "serves": ["US-01-001"], "states": ["loading", "empty", "error", "success"], "path": "screens/orders/S-01-orders.html"},
    {"key": "orders/S-02", "name": "Done", "purpose": "receipt", "platform": "both", "serves": ["US-01-001"], "states": ["loading", "empty", "error", "success"], "path": "screens/orders/S-02-done.html"}
  ],
  "concerns": [],
  "audit": null
}
JSON
}

t_begin "ux on a chosen HTML stack runs the flows, contrast and screen-state checkers"
at ux; profile yes no no no html
assert_exit 1 ap "done" ux
assert_contains "$T_OUT" "no docs/design/flows/*/flows*.md (ux-flows)"
flows "$d/docs/design/flows/orders/flows.md"
tokens "$d/docs/design/tokens.json" "text-muted=oklch(0.8 0 0)"
screen "$d/docs/design/screens/orders/S-01-orders.html" S-02-done.html loading empty error success
screen "$d/docs/design/screens/orders/S-02-done.html" "" loading empty error success
assert_exit 1 ap "done" ux
assert_contains "$T_OUT" "contrast failed"
tokens "$d/docs/design/tokens.json"
assert_exit 1 ap "done" ux
assert_contains "$T_OUT" "bundle check failed"
assert_contains "$T_OUT" "0 screens (0 features)"
manifest "$d/docs/design"
assert_exit 1 ap "done" ux
assert_contains "$T_OUT" "bundle check failed"
assert_contains "$T_OUT" "2 screens (1 features), 8 state panels"
assert_contains "$T_OUT" "2 problems"
BUNDLE="$KIT/plugins/bearing/skills/screen-design/scripts/bundle.py"
python3 "$BUNDLE" audit --design "$d/docs/design" --flows-root "$d/docs/design/flows" >/dev/null
python3 "$BUNDLE" gallery --design "$d/docs/design" >/dev/null
assert_exit 0 ap "done" ux
assert_contains "$T_OUT" "flows: 1 file(s) passed; tokens: contrast passed; screens: 1 feature(s) passed; design-bundle check: 2 screens (1 features), 8 state panels"
assert_contains "$T_OUT" ", 0 problems"
t_end

# The default react-shadcn stack: the design is code. A direction chosen from
# three scored variants, a motion spec, screens as *.screen.tsx in the
# gallery with every state, and design-lint over the app.
gallery_screen() { # gallery_screen <file> <id> <state>...
  local f="$1" id="$2"; shift 2; mkdir -p "$(dirname "$f")"
  { echo 'import type { ScreenSpec } from "@/design/screen";'
    echo 'import { Table } from "@/components/ui/table";'
    echo "export const screen: ScreenSpec = { id: \"$id\", name: \"x\", feature: \"orders\", job: \"x\","
    echo '  states: {'
    for st in "$@"; do echo "    $st: () => <Table />,"; done
    echo '  },'
    echo '};'
  } > "$f"
}

t_begin "ux on the default react-shadcn stack needs a chosen direction, motion, the gallery and design-lint"
at ux; profile yes no no no
flows "$d/docs/design/flows/orders/flows.md"; tokens "$d/docs/design/tokens.json"
assert_exit 1 ap "done" ux
assert_contains "$T_OUT" "no chosen design direction: docs/design/variants/*/approved.json (design-directions)"
mkdir -p "$d/docs/design/variants/app"
printf '{"chosen": "2-ledger", "scores": {"1-quiet": 7.1, "2-ledger": 8.6}}\n' > "$d/docs/design/variants/app/approved.json"
assert_exit 1 ap "done" ux
assert_contains "$T_OUT" "2 scored variants; a direction is chosen from 3"
printf '{"chosen": "2-ledger", "scores": {"1-quiet": 7.1, "2-ledger": 8.6, "3-grid": 7.9}}\n' > "$d/docs/design/variants/app/approved.json"
assert_exit 1 ap "done" ux
assert_contains "$T_OUT" "no docs/design/motion.md (motion-design)"
printf '# Motion\n' > "$d/docs/design/motion.md"
assert_exit 1 ap "done" ux
assert_contains "$T_OUT" "no design gallery: src/design/screen.ts or web/src/design/screen.ts (react-web template)"
mkdir -p "$d/web/src/design"; printf 'export interface ScreenSpec { id: string }\n' > "$d/web/src/design/screen.ts"
gallery_screen "$d/web/src/features/orders/screens/S-01-orders.screen.tsx" S-01 loading empty error success
assert_exit 1 ap "done" ux
assert_contains "$T_OUT" "gallery_check failed: screen-gallery: 2 screens from docs/design/flows/orders/flows.md"
gallery_screen "$d/web/src/features/orders/screens/S-02-done.screen.tsx" S-02 loading empty error success
assert_exit 1 ap "done" ux
assert_contains "$T_OUT" "no scripts/design-lint.sh (design-system)"
mkdir -p "$d/scripts"; cp "$KIT/plugins/bearing/skills/design-system/templates/design-lint.sh" "$d/scripts/design-lint.sh"
printf 'export const Bad = () => <button type="button">Go</button>;\n' > "$d/web/src/features/orders/Bad.tsx"
assert_exit 1 ap "done" ux
assert_contains "$T_OUT" "design-lint failed"
rm "$d/web/src/features/orders/Bad.tsx"
assert_exit 0 ap "done" ux
assert_contains "$T_OUT" "direction: 2-ledger of 3 scored variants; motion spec; screen-gallery: 2 screens"
assert_contains "$T_OUT" "design-lint passed"
t_end

t_begin "ux and design review pass without a UI in the profile"
at ux; profile no yes yes yes
assert_exit 0 ap "done" ux
assert_contains "$T_OUT" "no UI in the profile"
t_end

backlog() { mkdir -p "$(dirname "$1")"; cat > "$1" <<'MD'
### US-01-001 Sign in
- AC-US-01-001-1. Given a user, when they sign in, then the dashboard shows.
- AC-US-01-001-2. Given four failures, when a fifth fails, then the account locks.
MD
}
cases() { mkdir -p "$(dirname "$1")"
  { echo '| TC | Story | ACs | Title | Expected result | Oracles | Type | Priority | Automation |'
    echo '| --- | --- | --- | --- | --- | --- | --- | --- | --- |'
    echo "| TC-0001 | US-01-001 | AC-US-01-001-1 | Valid sign in | dashboard | $2 | e2e | P1 | planned |"
    echo "| TC-0002 | US-01-001 | AC-US-01-001-2 | Lockout | locked | data: GET /users/1 returns locked=true | integration | P2 | manual-only |"
  } > "$1"
}

t_begin "test cases run cases_check against the backlog"
at test_cases; profile yes no no no
backlog "$d/docs/product/backlog.md"
assert_exit 1 ap "done" test_cases
assert_contains "$T_OUT" "no docs/testing/test-cases.md (test-cases)"
cases "$d/docs/testing/test-cases.md" "works"
assert_exit 1 ap "done" test_cases
assert_contains "$T_OUT" "cases_check failed"
cases "$d/docs/testing/test-cases.md" "ui: heading 'Dashboard' visible; not: no error alert"
assert_exit 1 ap "done" test_cases
assert_contains "$T_OUT" "no risk register"
printf '| Risk | Story | What could go wrong | Source | Likelihood | Impact | Level | Cases |\n| R-001 | US-01-001 | lockout bypassed | AC-US-01-001-2 | M | M | Medium | TC-0001, TC-0002 |\n' > "$d/docs/testing/risks.md"
assert_exit 0 ap "done" test_cases
assert_contains "$T_OUT" "test-cases: 2 ACs, 2 with cases"
t_end

t_begin "test automation needs every automatable TC id named by a test"
at test_automation; profile yes no no no
cases "$d/docs/testing/test-cases.md" "ui: heading 'Dashboard' visible; not: no error alert"
mkdir -p "$d/e2e"; printf 'test("sign in", () => {});\n' > "$d/e2e/sign-in.spec.ts"; commit tests
( cd "$d" && make -s check )
assert_exit 1 ap "done" test_automation
assert_contains "$T_OUT" "1 automatable case(s) with no test naming them: TC-0001"
sleep 1; printf 'test("TC-0001 valid sign in", () => {});\n' > "$d/e2e/sign-in.spec.ts"
assert_exit 1 ap "done" test_automation
assert_contains "$T_OUT" "make check has not passed since"
( cd "$d" && make -s check )
assert_exit 0 ap "done" test_automation
assert_contains "$T_OUT" "1 of 1 automatable case(s) named by a test (1 manual-only or retired)"
t_end

# test-automation names a Python test test_tc_0001_<what>: the _ after the
# id is a word character, so a \b after the id never matched its own naming.
t_begin "test automation accepts test_tc_0001_<what>, and TC-00012 does not name TC-0001"
at test_automation; profile yes no no no
cases "$d/docs/testing/test-cases.md" "ui: heading 'Dashboard' visible; not: no error alert"
mkdir -p "$d/tests"; printf 'def test_tc_00012_other():\n    pass\n' > "$d/tests/test_sign_in.py"; commit tests
( cd "$d" && make -s check )
assert_exit 1 ap "done" test_automation
assert_contains "$T_OUT" "1 automatable case(s) with no test naming them: TC-0001"
sleep 1; printf 'def test_tc_0001_valid_sign_in():\n    pass\n' > "$d/tests/test_sign_in.py"
( cd "$d" && make -s check )
assert_exit 0 ap "done" test_automation
assert_contains "$T_OUT" "1 of 1 automatable case(s) named by a test"
t_end

# review <file> <overall> <typography score> <evidence line>: a report in the
# design-critique contract with eleven categories.
review() {
  mkdir -p "$(dirname "$1")"
  { echo "## Design review: app (round 1 of 3)"
    echo "Pages: 3   Evidence: $4"
    echo "| Category | Score | Weight | Evidence |"
    echo "| --- | --- | --- | --- |"
    for c in hierarchy spacing colour states responsive accessibility consistency; do echo "| $c | 8 | 10% | S-10-1440.png |"; done
    echo "| typography | $3 | 15% | S-10-1440.png |"
    echo "| copy | 9 | 5% | S-10-1440.png |"
    echo "| motion | n/a: static prototypes | 5% | none |"
    echo "| slop | 10 | 5% | none |"
    echo "Overall: $2 (B)   Slop hits: 0"
  } > "$1"
}
EV='design-evidence: 3 pages, 18 of 18 screenshots present (375/768/1440 light and dark), 9 of 9 dark shots differ from light, 0 problems'

t_begin "design review needs a scored review at the bar, with full evidence"
at design_review; profile yes no no no
assert_exit 1 ap "done" design_review
assert_contains "$T_OUT" "no docs/design/reviews/*-review.md (design-critique)"
review "$d/docs/design/reviews/app-review.md" 7.4 8 "$EV"
assert_exit 1 ap "done" design_review
assert_contains "$T_OUT" "overall 7.4 is below 8.0"
review "$d/docs/design/reviews/app-review.md" 8.3 6 "$EV"
assert_exit 1 ap "done" design_review
assert_contains "$T_OUT" "typography scored 6, below 7"
review "$d/docs/design/reviews/app-review.md" 8.3 8 "design-evidence: 3 pages, 12 of 18 screenshots present (375/768/1440 light and dark), 9 of 9 dark shots differ from light, 0 problems"
assert_exit 1 ap "done" design_review
assert_contains "$T_OUT" "evidence incomplete: 12 of 18 screenshots"
review "$d/docs/design/reviews/app-review.md" 8.3 8 "$EV"
assert_exit 0 ap "done" design_review
assert_contains "$T_OUT" "overall 8.3; 10 categories scored, none below 7, 1 n/a; 18 of 18 screenshots, 9 of 9 dark shots differ"
t_end

t_begin "dod refuses a profile the code contradicts"
at dod; profile no no no no
git -C "$d" checkout -q -b feature/T-9-x
mkdir -p "$d/web" "$d/migrations"
printf '{"dependencies":{"react":"19.0.0"}}\n' > "$d/web/package.json"
printf 'create table t (id int);\n' > "$d/migrations/0001_init.sql"; commit feat
( cd "$d" && make -s check )
assert_exit 1 ap "done" dod
assert_contains "$T_OUT" "the profile says ui=no, but web/package.json is a UI"
assert_contains "$T_OUT" "the profile says data=no, but migrations/0001_init.sql is a schema"
t_end

t_summary
