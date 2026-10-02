#!/usr/bin/env bash
# tests/unit/test_cases_refs.sh: plugins/bearing/skills/test-cases/scripts/cases_check.py
# (every AC has a live case, every case has tagged oracles, a P1 case has two
# categories including not:, every story and threat has a risk and every risk
# has the cases its level needs; --steps gives every manual and e2e case its
# steps; --plan quotes the gate and places every case in a scenario) and
# plugins/bearing/skills/test-automation/scripts/ref_check.py
# (test ids, names and routes a generated test uses exist in the source), each
# with its empty-input failure.
set -u
. "$(dirname "$0")/../lib/assert.sh"
CC="$KIT/plugins/bearing/skills/test-cases/scripts/cases_check.py"
RC="$KIT/plugins/bearing/skills/test-automation/scripts/ref_check.py"

backlog() { cat > "$1" <<'MD'
### US-01-001 Sign in
- AC-US-01-001-1. Given a user, when they sign in, then the dashboard shows.
- AC-US-01-001-2. Given four failures, when a fifth fails, then the account locks.
### US-01-002 Old export (withdrawn: dropped)
- AC-US-01-002-1. Given data, when exported, then a file downloads.
MD
}
risks() { # risks <file> <row...>: the register with the given rows
  local f="$1"; shift
  { echo '| Risk | Story | What could go wrong | Source | Likelihood | Impact | Level | Cases |'
    echo '| --- | --- | --- | --- | --- | --- | --- | --- |'
    for r in "$@"; do echo "$r"; done
  } > "$f"
}
ok_risk='| R-001 | US-01-001 | a locked account signs in | AC-US-01-001-2 | M | M | Medium | TC-0001, TC-0002 |'
cases() { # cases <file> <oracles for TC-0001> <oracles for TC-0002>
  { echo '| TC | Story | ACs | Title | Expected result | Oracles | Type | Priority | Automation |'
    echo '| --- | --- | --- | --- | --- | --- | --- | --- | --- |'
    echo "| TC-0001 | US-01-001 | AC-US-01-001-1 | Valid sign in | dashboard | $2 | e2e | P1 | planned |"
    echo "| TC-0002 | US-01-001 | AC-US-01-001-2 | Lockout | locked | $3 | integration | P2 | planned |"
  } > "$1"
}

t_begin "cases with tagged oracles cover every live AC"
d="$(tmpdir)"; backlog "$d/b.md"; risks "$d/r.md" "$ok_risk"
cases "$d/c.md" "ui: heading 'Dashboard' visible; not: no error alert" "data: GET /users/1 returns locked=true"
assert_exit 0 python3 "$CC" --backlog "$d/b.md" --cases "$d/c.md" --risks "$d/r.md" --threats "$d/tm-*.md"
assert_contains "$T_OUT" "test-cases: 2 ACs, 2 with cases, 2 live cases, 2 with oracles, 1 risks (high 0, medium 1, low 0), 0 threats traced from 0 threat models, 0 problems"
t_end

t_begin "a story withdrawn on its Status line is skipped, as the backlog gate reads it"
d="$(tmpdir)"; backlog "$d/b.md"; risks "$d/r.md" "$ok_risk"
printf '### US-01-003 Old import\n\nStatus: withdrawn: 2026-10-01, no CMS\n- AC-US-01-003-1. Given a file, when imported, then rows appear.\n' >> "$d/b.md"
cases "$d/c.md" "ui: heading 'Dashboard' visible; not: no error alert" "data: GET /users/1 returns locked=true"
assert_exit 0 python3 "$CC" --backlog "$d/b.md" --cases "$d/c.md" --risks "$d/r.md" --threats "$d/tm-*.md"
assert_contains "$T_OUT" "test-cases: 2 ACs, 2 with cases"
t_end

t_begin "a weak P1, an untagged or vague check, and an uncovered AC fail"
d="$(tmpdir)"; backlog "$d/b.md"; risks "$d/r.md" "$ok_risk"
cases "$d/c.md" "ui: heading visible" "it works; data: as expected"
assert_exit 1 python3 "$CC" --backlog "$d/b.md" --cases "$d/c.md" --risks "$d/r.md" --threats "$d/tm-*.md"
assert_contains "$T_OUT" "TC-0001: P1 needs two oracle categories including not: (has ui)"
assert_contains "$T_OUT" "TC-0002: no oracle"
sed -i.bak 's/AC-US-01-001-2/AC-US-01-001-9/' "$d/c.md"
assert_exit 1 python3 "$CC" --backlog "$d/b.md" --cases "$d/c.md" --risks "$d/r.md" --threats "$d/tm-*.md"
assert_contains "$T_OUT" "AC-US-01-001-2: no live case"
t_end

t_begin "a retired row does not cover; a duplicate id fails; empty input fails"
d="$(tmpdir)"; backlog "$d/b.md"; risks "$d/r.md" "$ok_risk"
cases "$d/c.md" "ui: x shown; not: no alert" "data: row locked"
sed -i.bak 's/| integration | P2 | planned |/| integration | P2 | retired |/' "$d/c.md"
assert_exit 1 python3 "$CC" --backlog "$d/b.md" --cases "$d/c.md" --risks "$d/r.md" --threats "$d/tm-*.md"
assert_contains "$T_OUT" "AC-US-01-001-2: no live case"
cases "$d/c.md" "ui: x shown; not: no alert" "data: row locked"
sed -i.bak 's/TC-0002/TC-0001/' "$d/c.md"
assert_exit 1 python3 "$CC" --backlog "$d/b.md" --cases "$d/c.md" --risks "$d/r.md" --threats "$d/tm-*.md"
assert_contains "$T_OUT" "TC-0001: duplicate id"
printf '# none\n' > "$d/b.md"
assert_exit 1 python3 "$CC" --backlog "$d/b.md" --cases "$d/c.md" --risks "$d/r.md" --threats "$d/tm-*.md"
assert_contains "$T_OUT" "0 acceptance criteria"
printf '| TC | Story |\n' > "$d/c.md"; backlog "$d/b.md"
assert_exit 1 python3 "$CC" --backlog "$d/b.md" --cases "$d/c.md" --risks "$d/r.md" --threats "$d/tm-*.md"
assert_contains "$T_OUT" "0 TC rows"
t_end

t_begin "risks: level follows the scale, depth follows the level, stories and threats are covered"
d="$(tmpdir)"; backlog "$d/b.md"
cases "$d/c.md" "ui: heading 'Dashboard' visible; not: no error alert" "data: GET /users/1 returns locked=true"
RUN() { python3 "$CC" --backlog "$d/b.md" --cases "$d/c.md" --risks "$d/r.md" --threats "$d/tm-*.md"; }
risks "$d/r.md" '| R-001 | US-01-001 | lockout bypassed | AC-US-01-001-2 | M | H | Medium | TC-0001 |'
assert_exit 1 RUN
assert_contains "$T_OUT" "R-001: level is High for likelihood M and impact H, not 'Medium'"
assert_contains "$T_OUT" "R-001: High needs 3 live cases, has 1"
risks "$d/r.md" '| R-001 | US-01-001 | lockout bypassed | AC-US-01-001-2 | M | M | Medium | TC-0002, TC-0009 |'
assert_exit 1 RUN
assert_contains "$T_OUT" "R-001: TC-0009 is not a live case"
assert_contains "$T_OUT" "R-001: Medium needs a case with a not: oracle"
risks "$d/r.md" '| R-001 | US-09-009 | elsewhere | change size | L | L | Low | TC-0001 |'
assert_exit 1 RUN
assert_contains "$T_OUT" "US-01-001: no risk in"
printf '| Id | Entry | Category | Threat | Likelihood | Impact | Mitigation | Status |\n| T-01 | E1 | Elevation | reads another tenant | M | H | new story: x | planned |\n| T-02 | E1 | Repudiation | considered, none: audit log | | | | |\n' > "$d/tm-a.md"
risks "$d/r.md" "$ok_risk"
assert_exit 1 RUN
assert_contains "$T_OUT" "T-01: threat is the source of no risk"
assert_not_contains "$T_OUT" "T-02"
risks "$d/r.md" "$ok_risk" '| R-002 | US-01-001 | tenant leak | T-01 | L | H | Medium | TC-0001, TC-0002 |'
assert_exit 0 RUN
assert_contains "$T_OUT" "2 risks (high 0, medium 2, low 0), 1 threats traced from 1 threat models, 0 problems"
t_end

t_begin "a missing or empty risk register fails"
d="$(tmpdir)"; backlog "$d/b.md"
cases "$d/c.md" "ui: heading 'Dashboard' visible; not: no error alert" "data: GET /users/1 returns locked=true"
assert_exit 1 python3 "$CC" --backlog "$d/b.md" --cases "$d/c.md" --risks "$d/none.md"
assert_contains "$T_OUT" "no risk register at $d/none.md"
risks "$d/r.md"
assert_exit 1 python3 "$CC" --backlog "$d/b.md" --cases "$d/c.md" --risks "$d/r.md"
assert_contains "$T_OUT" "0 R-nnn rows"
t_end

t_begin "types are counted; --steps needs steps for every manual and e2e case"
d="$(tmpdir)"; backlog "$d/b.md"; risks "$d/r.md" "$ok_risk"
cases "$d/c.md" "ui: heading 'Dashboard' visible; not: no error alert" "data: GET /users/1 returns locked=true"
RUN() { python3 "$CC" --backlog "$d/b.md" --cases "$d/c.md" --risks "$d/r.md" --threats "$d/tm-*.md" "$@"; }
assert_exit 0 RUN
assert_contains "$T_OUT" "test-types: unit 0, integration 1, e2e 1, manual 0; by machine 2 (automated 0, planned 2), by hand 0"
assert_exit 1 RUN --steps "$d/none.md"
assert_contains "$T_OUT" "no step rows"
{ echo '| Step | Case | Action | Expected |'
  echo '| --- | --- | --- | --- |'
  echo '| TC-0002.1 | TC-0002 | POST /auth/login five times with a wrong password | 423 on the fifth |'
  echo '| TC-0009.1 | TC-0009 | Open /login | The form shows |'
  echo '| TC-0001.2 | TC-0002 | Press Sign in | works |'
} > "$d/s.md"
assert_exit 1 RUN --steps "$d/s.md"
assert_contains "$T_OUT" "TC-0001: e2e case has no steps in $d/s.md"
assert_contains "$T_OUT" "TC-0009.1: TC-0009 is not a live case"
assert_contains "$T_OUT" "TC-0001.2: Case column 'TC-0002' does not match the step id"
assert_contains "$T_OUT" "TC-0001.2: Expected 'works' is not a specific step"
{ echo '| Step | Case | Action | Expected |'
  echo '| --- | --- | --- | --- |'
  echo '| TC-0001.1 | TC-0001 | Open /login and sign in as user@example.test | The Dashboard heading shows |'
} > "$d/s.md"
assert_exit 0 RUN --steps "$d/s.md"
assert_contains "$T_OUT" "test-steps: 1 manual or e2e cases, 1 with steps, 1 steps"
t_end

t_begin "--plan: the plan quotes the gate, places every case and tags every concern"
d="$(tmpdir)"; backlog "$d/b.md"; risks "$d/r.md" "$ok_risk"
cases "$d/c.md" "ui: heading 'Dashboard' visible; not: no error alert" "data: GET /users/1 returns locked=true"
RUN() { python3 "$CC" --backlog "$d/b.md" --cases "$d/c.md" --risks "$d/r.md" --threats "$d/tm-*.md" "$@"; }
counts="$(python3 "$CC" --backlog "$d/b.md" --cases "$d/c.md" --risks "$d/r.md" --threats "$d/tm-*.md" | grep '^test-cases:')"
types="$(python3 "$CC" --backlog "$d/b.md" --cases "$d/c.md" --risks "$d/r.md" --threats "$d/tm-*.md" | grep '^test-types:')"
plan() { # plan <file> <scenario cases> <concern line>
  { echo '# Test plan'; echo; echo "Scenarios: 2"; echo "$counts"; echo "$types"
    echo '## Scenarios'; echo '| Scenario | Story | Title | Proves that | Cases |'; echo '| --- | --- | --- | --- | --- |'
    echo '| TS-US-01-001-1 | US-01-001 | Sign in | a valid user reaches the dashboard | TC-0001 |'
    echo "| TS-US-01-001-2 | US-01-001 | Lockout | five failures lock the account | $2 |"
    echo '## Entry criteria'; echo '- build deployed'; echo '## Exit criteria'; echo '- P1 cases pass'
    echo '## Environments'; echo '- chromium'; echo '## What QA raised while writing this'; echo "$3"
  } > "$1"
}
plan "$d/p.md" "TC-0002" "- [undefined] The lockout message text is not given."
assert_exit 0 RUN --plan "$d/p.md"
assert_contains "$T_OUT" "test-plan: 2 scenarios over 1 stories, 2 of 2 live cases placed, 1 concerns raised, 0 problems"
plan "$d/p.md" "TC-0007" "- The lockout message text is not given."
assert_exit 1 RUN --plan "$d/p.md"
assert_contains "$T_OUT" "TS-US-01-001-2: TC-0007 is not a live case"
assert_contains "$T_OUT" "TC-0002: in no scenario of $d/p.md"
assert_contains "$T_OUT" "concern not tagged"
plan "$d/p.md" "TC-0002" "- [risk] ok"
sed -i.bak 's/^test-cases: 2 ACs/test-cases: 3 ACs/; s/^Scenarios: 2/Scenarios: 5/; /^## Exit criteria/d' "$d/p.md"
assert_exit 1 RUN --plan "$d/p.md"
assert_contains "$T_OUT" "does not quote this run's test-cases line verbatim"
assert_contains "$T_OUT" "'Scenarios: 5' does not match 2 scenario rows"
assert_contains "$T_OUT" "no 'Exit criteria' section"
assert_exit 1 RUN --plan "$d/missing.md"
assert_contains "$T_OUT" "no test plan at $d/missing.md"
t_end

t_begin "--plan: claiming every criterion has a case while one has none fails"
d="$(tmpdir)"; backlog "$d/b.md"; risks "$d/r.md" "$ok_risk"
cases "$d/c.md" "ui: heading 'Dashboard' visible; not: no error alert" "data: GET /users/1 returns locked=true"
sed -i.bak 's/AC-US-01-001-2 | Lockout/AC-US-01-001-1 | Lockout/' "$d/c.md"
printf 'Every acceptance criterion in the backlog has at least one case.\n' > "$d/p.md"
assert_exit 1 python3 "$CC" --backlog "$d/b.md" --cases "$d/c.md" --risks "$d/r.md" --threats "$d/tm-*.md" --plan "$d/p.md"
assert_contains "$T_OUT" "claims every criterion has a case while 1 have none"
t_end

src() { # a tiny web app: one screen, one API route
  mkdir -p "$1/src/app" "$1/src/api" "$1/e2e"
  printf '<button data-testid="save-btn">Save invoice</button><label>Email</label>\n' > "$1/src/app/page.tsx"
  printf 'router.get("/api/invoices/:id", h)\n' > "$1/src/api/routes.ts"
}

t_begin "a name the source builds in a template literal is found; a different one is not"
d="$(tmpdir)"; src "$d"
printf 'export const deleteLabel = (n: number) => `Delete up to ${n} records`;\n' > "$d/src/copy.ts"
cat > "$d/e2e/tpl.spec.ts" <<'TS'
test("TC-0003 deletes", async ({ page }) => {
  await page.getByRole("button", { name: "Delete up to 3 records" }).click();
  await page.getByText("Remove up to 3 records").isVisible();
});
TS
assert_exit 1 python3 "$RC" --src "$d/src" "$d/e2e/tpl.spec.ts"
assert_not_contains "$T_OUT" "'Delete up to 3 records'"
assert_contains "$T_OUT" "name 'Remove up to 3 records' is not in the source"
t_end

t_begin "an id: field in test data is not a test id; a directory among the tests fails"
d="$(tmpdir)"; src "$d"
cat > "$d/e2e/data.spec.ts" <<'TS'
const slot = {
  id: "00000000-0000-0000-0000-0000000005a1",
};
test("TC-0004 books", async ({ page }) => {
  await page.getByTestId("save-btn").click();
});
TS
assert_exit 0 python3 "$RC" --src "$d/src" "$d/e2e/data.spec.ts"
assert_contains "$T_OUT" "1 references (ids 1, names 0, paths 0), 0 missing"
mkdir -p "$d/content"
assert_exit 1 python3 "$RC" --src "$d/src" "$d/content" "$d/e2e/data.spec.ts"
assert_contains "$T_OUT" "content: not a test file (a second source directory needs its own --src)"
t_end

t_begin "references that exist pass; invented ones are named"
d="$(tmpdir)"; src "$d"
cat > "$d/e2e/tc.spec.ts" <<'TS'
test("TC-0001 saves", async ({ page, request }) => {
  await page.goto("/");
  await page.getByTestId("save-btn").click();
  await page.getByRole("button", { name: "Save invoice" }).click();
  await page.getByLabel("Email").fill("a@example.test");
  await request.get("/api/invoices/42");
});
TS
assert_exit 0 python3 "$RC" --src "$d/src" "$d/e2e/tc.spec.ts"
assert_contains "$T_OUT" "test-refs: 1 test files, 5 references (ids 1, names 2, paths 2), 0 missing"
cat > "$d/e2e/bad.spec.ts" <<'TS'
test("TC-0002 invents", async ({ page, request }) => {
  await page.getByTestId("submit-button").click();
  await page.getByText("Invoice saved!").isVisible();
  await request.post("/api/v2/invoices");
});
TS
assert_exit 1 python3 "$RC" --src "$d/src" "$d/e2e/bad.spec.ts"
assert_contains "$T_OUT" "id 'submit-button' is not in the source"
assert_contains "$T_OUT" "name 'Invoice saved!' is not in the source"
assert_contains "$T_OUT" "path 'POST /api/v2/invoices' is not in the source"
assert_contains "$T_OUT" "3 missing"
t_end

t_begin "no test files, and zero references, fail and print the count"
d="$(tmpdir)"; src "$d"
assert_exit 1 python3 "$RC" --src "$d/src"
assert_contains "$T_OUT" "0 test files, nothing checked"
printf 'def test_tc_0003_adds():\n    assert add(1, 2) == 3\n' > "$d/test_math.py"
assert_exit 1 python3 "$RC" --src "$d/src" "$d/test_math.py"
assert_contains "$T_OUT" "1 test files, 0 references"
assert_contains "$T_OUT" "this gate did not pass"
assert_exit 2 python3 "$RC" --src "$d/src" --allow-none "$d/test_math.py"
t_end

goapi() { # a Go service whose routes use the 1.22 "METHOD /path/{id}" pattern
  mkdir -p "$1/internal/refunds"
  cat > "$1/internal/refunds/handler.go" <<'GO'
package refunds
func Routes(mux *http.ServeMux) {
	mux.HandleFunc("POST /orders/{id}/refunds", create)
	mux.HandleFunc("GET /orders/{id}/refunds", list)
}
GO
}

t_begin "Go routes reached through a helper such as do() are checked, not skipped"
d="$(tmpdir)"; goapi "$d"
cat > "$d/internal/refunds/refunds_test.go" <<'GO'
func TestTC0103_PartialRefund(t *testing.T) {
	rec := do(t, h, http.MethodPost, "/orders/ord_1/refunds", `{"amount_paise":25000}`)
	sum := do(t, h, http.MethodGet, "/orders/"+id+"/refunds", "")
}
GO
assert_exit 0 python3 -W error "$RC" --src "$d/internal" "$d/internal/refunds/refunds_test.go"
assert_contains "$T_OUT" "2 references (ids 0, names 0, paths 2), 0 missing"
cat > "$d/internal/refunds/receipt_test.go" <<'GO'
func TestTC0107_Receipt(t *testing.T) {
	rec := do(t, h, http.MethodGet, "/refunds/ref_1/receipt", "")
	del := do(t, h, http.MethodDelete, "/orders/ord_1/refunds", "")
}
GO
assert_exit 1 python3 "$RC" --src "$d/internal" "$d/internal/refunds/receipt_test.go"
assert_contains "$T_OUT" "path 'GET /refunds/ref_1/receipt' is not in the source"
assert_contains "$T_OUT" "path 'DELETE /orders/ord_1/refunds' is not in the source"
t_end

t_begin "Python regex routes: a SKU value matches the pattern, a method the table lacks does not"
d="$(tmpdir)"; mkdir -p "$d/stock" "$d/tests"
cat > "$d/stock/app.py" <<'PY2'
ROUTES = [
    ("GET", r"/items/(?P<sku>[A-Z0-9-]+)", get_item),
    ("POST", r"/items/(?P<sku>[A-Z0-9-]+)/adjust", adjust),
]
PY2
cat > "$d/tests/test_items.py" <<'PY2'
def test_tc_0012_get(client):
    client.get("/items/WIDGET-1")
    call("POST", "/items/WIDGET-1/adjust")
PY2
assert_exit 0 python3 "$RC" --src "$d/stock" "$d/tests/test_items.py"
assert_contains "$T_OUT" "2 references (ids 0, names 0, paths 2), 0 missing"
printf 'def test_tc_0014_delete(client):\n    client.delete("/items/WIDGET-1")\n' > "$d/tests/test_delete.py"
assert_exit 1 python3 "$RC" --src "$d/stock" "$d/tests/test_delete.py"
assert_contains "$T_OUT" "path 'DELETE /items/WIDGET-1' is not in the source"
printf 'def test_tc_0015_unknown(client):\n    client.delete("/items/WIDGET-1")  # ref_check: absent\n' > "$d/tests/test_unknown.py"
assert_exit 0 python3 "$RC" --src "$d/stock" "$d/tests/test_unknown.py"
assert_contains "$T_OUT" "1 declared absent"
printf 'def test_tc_0016_lie(client):\n    client.get("/items/WIDGET-1")  # ref_check: absent\n' > "$d/tests/test_lie.py"
assert_exit 1 python3 "$RC" --src "$d/stock" "$d/tests/test_lie.py"
assert_contains "$T_OUT" "marked absent but the source serves it"
t_end

t_summary
