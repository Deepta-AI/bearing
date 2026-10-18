#!/usr/bin/env bash
# tests/unit/screen_data_needs.sh: states_check.py --needs checks a feature's
# data-needs.md against the flows inventory: every screen has an entry, every
# server action names its outcomes with a status and a code, every empty,
# loading and error state has a server condition, ids are unique, and zero
# input fails. parse_needs and outcomes are importable without side effects.
set -u
. "$(dirname "$0")/../lib/assert.sh"
CHK="$KIT/plugins/bearing/skills/screen-design/scripts/states_check.py"
FX="$KIT/tests/fixtures/data-needs"

# fx: copy the fixture into a fresh directory and print it.
fx() { d="$(tmpdir)"; cp "$FX/flows.md" "$FX/data-needs.md" "$d/"; printf '%s' "$d"; }

t_begin "a complete needs file passes with its counts"
assert_exit 0 python3 "$CHK" --needs "$FX/data-needs.md" --flows "$FX/flows.md"
assert_contains "$T_OUT" "data-needs: 2 screens, 2 fields, 2 actions (1 exists, 1 new), 3 outcomes, 5 states, 0 problems"
t_end

t_begin "a screen with no entry, an action with no outcome and an uncovered error state fail"
d="$(fx)"
replace_in "$d/data-needs.md" "| A-01 | Send invite | create an invite | 201 created; 409 already_member | new |" "| A-01 | Send invite | create an invite | | new |"
replace_in "$d/data-needs.md" "| error: already_member | the invite call returns 409 already_member |" ""
python3 - "$d/data-needs.md" <<'PY'
import sys
t = open(sys.argv[1]).read()
open(sys.argv[1], "w").write(t[: t.index("## S-02 Invite")])
PY
assert_exit 1 python3 "$CHK" --needs "$d/data-needs.md" --flows "$d/flows.md"
assert_contains "$T_OUT" "S-02 has no entry in"
assert_contains "$T_OUT" "A-01 (S-01) has no outcome"
assert_contains "$T_OUT" "S-01 state error-already-member has no server condition"
t_end

t_begin "a client-only action needs no outcome; none: needs a reason"
d="$(fx)"
replace_in "$d/data-needs.md" "| A-02 | Revoke | revoke the invite | 204 revoked | exists |" "| A-02 | Pick a date | none: opens the picker locally | | |"
assert_exit 0 python3 "$CHK" --needs "$d/data-needs.md" --flows "$d/flows.md"
assert_contains "$T_OUT" "0 problems"
replace_in "$d/data-needs.md" "| F-01 | member.email | string | server | exists |" "| none: | | | | |"
assert_exit 1 python3 "$CHK" --needs "$d/data-needs.md" --flows "$d/flows.md"
assert_contains "$T_OUT" "none needs a reason"
t_end

t_begin "a status other than exists or new, and an outcome with no code, fail"
d="$(fx)"
replace_in "$d/data-needs.md" "| F-02 | invite.expires_at | datetime | server | new |" "| F-02 | invite.expires_at | datetime | server | maybe |"
replace_in "$d/data-needs.md" "| 204 revoked |" "| 204 |"
assert_exit 1 python3 "$CHK" --needs "$d/data-needs.md" --flows "$d/flows.md"
assert_contains "$T_OUT" "F-02 (S-02) status must be exists or new"
assert_contains "$T_OUT" 'A-02 (S-02) outcome "204" has no code (write <status> <code>)'
t_end

t_begin "an action id used on two screens fails"
d="$(fx)"
replace_in "$d/data-needs.md" "| A-02 | Revoke |" "| A-01 | Revoke |"
assert_exit 1 python3 "$CHK" --needs "$d/data-needs.md" --flows "$d/flows.md"
assert_contains "$T_OUT" "A-01 is used twice (S-01, S-02)"
t_end

t_begin "zero input fails"
d="$(fx)"
assert_exit 1 python3 "$CHK" --needs "$d/missing.md" --flows "$d/flows.md"
assert_contains "$T_OUT" "missing.md"
printf '## 1. Screen inventory\n\n## 2. Interaction states\n' > "$d/empty-flows.md"
assert_exit 1 python3 "$CHK" --needs "$d/data-needs.md" --flows "$d/empty-flows.md"
assert_contains "$T_OUT" "0 screens in the inventory"
t_end

t_begin "no actions at all fails with 0 actions; all client-only actions pass"
d="$(fx)"
replace_in "$d/data-needs.md" "| A-01 | Send invite | create an invite | 201 created; 409 already_member | new |" "| A-01 | Open picker | none: opens the picker locally | | |"
replace_in "$d/data-needs.md" "| A-02 | Revoke | revoke the invite | 204 revoked | exists |" "| A-02 | Pick a date | none: opens the picker locally | | |"
assert_exit 0 python3 "$CHK" --needs "$d/data-needs.md" --flows "$d/flows.md"
assert_contains "$T_OUT" "2 actions (0 exists, 0 new), 0 outcomes"
replace_in "$d/data-needs.md" "| A-01 | Open picker | none: opens the picker locally | | |" "| none: nothing to do | | | | |"
replace_in "$d/data-needs.md" "| A-02 | Pick a date | none: opens the picker locally | | |" "| none: nothing to do | | | | |"
assert_exit 1 python3 "$CHK" --needs "$d/data-needs.md" --flows "$d/flows.md"
assert_contains "$T_OUT" "0 actions in"
t_end

t_begin "bad ids fail naming the screen; --needs without --flows is a usage error"
d="$(fx)"
replace_in "$d/data-needs.md" "| A-01 | Send invite |" "| | Send invite |"
replace_in "$d/data-needs.md" "| F-02 |" "| X2 |"
assert_exit 1 python3 "$CHK" --needs "$d/data-needs.md" --flows "$d/flows.md"
assert_contains "$T_OUT" "action id must be A-<digits>"
assert_contains "$T_OUT" "in S-01"
assert_contains "$T_OUT" "field id must be F-<digits>"
assert_exit 2 python3 "$CHK" --needs "$d/data-needs.md"
assert_contains "$T_OUT" "--flows is required with --needs"
t_end

t_begin "the template, placeholders filled, passes against matching flows"
d="$(tmpdir)"
TPL="$KIT/plugins/bearing/skills/screen-design/templates/data-needs.md"
printf '## 1. Screen inventory\n\n| Id | Screen |\n| --- | --- |\n| S-01 | One |\n| S-02 | Two |\n\n## 2. Interaction states\n\n### S-01 One\n\n| State | Sees | Copy |\n| --- | --- | --- |\n| loading | x | y |\n\n### S-02 Two\n\n| State | Sees | Copy |\n| --- | --- | --- |\n| loading | x | y |\n' > "$d/flows.md"
fill() { sed -e 's/<screen name>/Screen/' -e 's/<object.field>/a.b/' -e 's/<type>/string/' -e 's#exists / new#new#' -e 's/<verb noun>/Send it/' -e 's/<what the server does>/sends/' -e 's/<status> <code>; <status> <code>/200 ok; 404 missing/' -e 's/<what is in flight>/a request/'; }
{ sed -n '1,/^## S-01/p' "$TPL" | sed '$d' | head -1; fill < "$TPL" | sed -n '/^## S-01/,$p'; fill < "$TPL" | sed -n '/^## S-01/,$p' | sed -e 's/S-01/S-02/' -e 's/F-01/F-02/' -e 's/A-01/A-02/'; } > "$d/data-needs.md"
assert_exit 0 python3 "$CHK" --needs "$d/data-needs.md" --flows "$d/flows.md"
assert_contains "$T_OUT" "0 problems"
t_end

t_begin "parse_needs and outcomes import without side effects"
out="$(python3 - "$FX/data-needs.md" <<PY
import importlib.util, sys
spec = importlib.util.spec_from_file_location("states_check", "$CHK")
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
n = m.parse_needs(open(sys.argv[1]).read())
print(sorted(n), len(n["S-01"]["actions"]), m.outcomes("201 created; 409 already_member"))
PY
)"
assert_contains "$out" "['S-01', 'S-02'] 1 [('201', 'created'), ('409', 'already_member')]"
t_end

t_summary
