#!/usr/bin/env bash
# tests/unit/api_data_needs.sh: api_doc.py needs checks an OpenAPI spec against
# the screens' data-needs.md files: every server action maps to an operation
# through x-data-needs, every outcome has a response, every named id exists,
# an action id lives in one file, and zero input fails with the counts.
set -u
. "$(dirname "$0")/../lib/assert.sh"
API="$KIT/plugins/bearing/skills/openapi-spec/scripts/api_doc.py"
FX="$KIT/tests/fixtures/data-needs"

# fx: copy the fixture into a fresh directory and print it.
fx() { d="$(tmpdir)"; cp "$FX/data-needs.md" "$FX/openapi.json" "$d/"; printf '%s' "$d"; }

t_begin "every action mapped and every outcome documented passes"
d="$(fx)"
assert_exit 0 python3 "$API" needs --spec "$d/openapi.json" --needs "$d/data-needs.md"
assert_contains "$T_OUT" "data needs: 3 actions, 3 mapped, 1 new operations; 4 outcomes, 0 without a response, 0 problems"
t_end

t_begin "an action no operation maps fails"
d="$(fx)"
replace_in "$d/openapi.json" '"x-data-needs": ["A-02"],' ''
assert_exit 1 python3 "$API" needs --spec "$d/openapi.json" --needs "$d/data-needs.md"
assert_contains "$T_OUT" "A-02 (Revoke) maps to no operation"
t_end

t_begin "an outcome with no response fails"
d="$(fx)"
replace_in "$d/openapi.json" ',
          "409": { "description": "already_member" }' ''
assert_exit 1 python3 "$API" needs --spec "$d/openapi.json" --needs "$d/data-needs.md"
assert_contains "$T_OUT" "A-01 outcome 409 already_member: no 409 response on POST /invites"
assert_contains "$T_OUT" "1 without a response"
t_end

t_begin "an id no data-needs file has fails"
d="$(fx)"
replace_in "$d/openapi.json" '"x-data-needs": ["A-01"]' '"x-data-needs": ["A-09"]'
assert_exit 1 python3 "$API" needs --spec "$d/openapi.json" --needs "$d/data-needs.md"
assert_contains "$T_OUT" "POST /invites x-data-needs names A-09, which no data-needs file has"
t_end

# billing <file> <action id>: a second feature's data needs with one server action.
billing() {
  printf '# Data needs: billing\n\n## S-01 Billing\n\n### Fields\n\n| Id | Field | Type | Source | Status |\n| --- | --- | --- | --- | --- |\n| F-10 | invoice.total | integer | server | new |\n\n### Actions\n\n| Id | Action | Server | Outcomes | Status |\n| --- | --- | --- | --- | --- |\n| %s | Pay invoice | charge the card | 200 paid; 402 card_declined | new |\n\n### States\n\n| State | Server condition |\n| --- | --- |\n| loading | the payment is in flight |\n' "$2" > "$1"
}
# pay <spec> <action id>: add the payment operation answering <action id>.
pay() {
  python3 - "$1" "$2" <<'PY2'
import json, sys
s = json.load(open(sys.argv[1]))
s["paths"]["/payments"] = {"post": {"x-story-ids": ["US-02-001"], "x-data-needs": [sys.argv[2]],
    "responses": {"200": {"description": "paid"}, "402": {"description": "card_declined"}}}}
json.dump(s, open(sys.argv[1], "w"))
PY2
}

t_begin "two features with ids unique across the product pass"
d="$(fx)"; billing "$d/billing.md" A-10; pay "$d/openapi.json" A-10
assert_exit 0 python3 "$API" needs --spec "$d/openapi.json" --needs "$d/data-needs.md" "$d/billing.md"
assert_contains "$T_OUT" ", 0 problems"
t_end

t_begin "an action id in two features' files fails, naming both and saying to renumber"
d="$(fx)"; billing "$d/billing.md" A-01; pay "$d/openapi.json" A-01
assert_exit 1 python3 "$API" needs --spec "$d/openapi.json" --needs "$d/data-needs.md" "$d/billing.md"
assert_contains "$T_OUT" "problem: A-01 is in two data-needs files ($d/data-needs.md, $d/billing.md)"
assert_contains "$T_OUT" "renumber"
t_end

t_begin "zero input fails: no operations, no actions, missing files"
d="$(fx)"
printf '{"openapi": "3.1.0", "paths": {}}\n' > "$d/empty.json"
assert_exit 1 python3 "$API" needs --spec "$d/empty.json" --needs "$d/data-needs.md"
assert_contains "$T_OUT" "0 operations in"
printf '# Data needs: none\n' > "$d/none.md"
assert_exit 1 python3 "$API" needs --spec "$d/openapi.json" --needs "$d/none.md"
assert_contains "$T_OUT" "0 actions in"
assert_exit 1 python3 "$API" needs --spec "$d/nope.json" --needs "$d/data-needs.md"
assert_contains "$T_OUT" "not found, nothing checked"
t_end

t_begin "only client-only actions pass with the server count at zero"
d="$(fx)"
replace_in "$d/data-needs.md" "| A-01 | Send invite | create an invite | 201 created; 409 already_member | new |" "| A-01 | Pick a date | none: opens the picker locally | | |"
replace_in "$d/data-needs.md" "| A-02 | Revoke | revoke the invite | 204 revoked | exists |" "| A-02 | Cancel | none: closes the dialog | | |"
replace_in "$d/data-needs.md" "| A-03 | Load members | list the members | 200 members | exists |" "| A-03 | Sort | none: sorts the list locally | | |"
printf '{"openapi": "3.1.0", "paths": {"/health": {"get": {"responses": {"200": {"description": "ok"}}}}}}\n' > "$d/openapi.json"
assert_exit 0 python3 "$API" needs --spec "$d/openapi.json" --needs "$d/data-needs.md"
assert_contains "$T_OUT" "data needs: 3 actions, 0 server, 0 mapped, 0 new operations"
t_end

t_summary
