#!/usr/bin/env bash
# tests/unit/traceability_check.sh: skills/traceability/scripts/trace_check.py
# passes a fully traced repository and fails, naming the class, on each gap
# class (REQ without story, story without AC, AC without TC, TC without test,
# story without ticket, ticket without commits, boundary change without ADR,
# event not in sheet, missing source), marks the ticket classes n/a under
# tracker none, and fails on empty input.
set -u
. "$(dirname "$0")/../lib/assert.sh"
CHK="$KIT/skills/traceability/scripts/trace_check.py"

# fixture <dir>: two REQ, two stories with tickets, cases, a test, a log, an ADR, a sheet.
fixture() {
  mkdir -p "$1/docs/product" "$1/docs/testing" "$1/docs/adr" "$1/docs/analytics" "$1/src"
  printf '| Id | Statement |\n| --- | --- |\n| REQ-001 | Sign in |\n| REQ-002 | Export |\n| REQ-009 | withdrawn: old |\n' > "$1/docs/product/PRD.md"
  cat > "$1/docs/product/backlog.md" <<'MD'
## EP-01 Accounts

### US-01-001 Sign in

Ticket: PROJ-1
Covers: REQ-001
Events: `login_done`

- AC-US-01-001-1. Given a user, when they sign in, then the dashboard shows.
  Covers: REQ-001

### US-01-002 Export

Ticket: PROJ-2
Covers: REQ-002

- AC-US-01-002-1. Given data, when exported, then a file downloads.
  Covers: REQ-002
MD
  { echo '| TC | Story | ACs | Title | Status |'
    echo '| --- | --- | --- | --- | --- |'
    echo '| TC-0001 | US-01-001 | AC-US-01-001-1 | sign in | active |'
    echo '| TC-0002 | US-01-002 | AC-US-01-002-1 | export | active |'
    echo '| TC-0003 | US-01-002 | AC-US-01-002-1 | old | retired |'
  } > "$1/docs/testing/test-cases.md"
  printf "it('TC-0001 signs in', () => {});\nit('TC-0002 exports US-01-002', () => {});\n" > "$1/src/app.test.ts"
  printf '# ADR-0001 Add the CSV library\n\nFor PROJ-2.\n' > "$1/docs/adr/0001-csv-library.md"
  printf '| Event | Added in |\n| --- | --- |\n| `login_done` | US-01-001 |\n' > "$1/docs/analytics/EVENT_SHEET.md"
  printf '@@commit a1\n[PROJ-1] feat: sign in\n\n@@files\n\nsrc/login.ts\n@@commit b2\n[PROJ-2] feat: export\n\n@@files\n\ngo.mod\nsrc/export.ts\n' > "$1/git.log"
}
run() { (cd "$1" && python3 "$CHK" --log git.log "${@:2}"); }

t_begin "a traced repository passes with its counts"
d="$(tmpdir)/ok"; fixture "$d"
assert_exit 0 run "$d"
assert_contains "$T_OUT" "Ids: REQ 2, US 2, AC 2, TC 2, tests 1, tickets 2, ADR 1, events 1"
assert_contains "$T_OUT" "Links: REQ>US 2, US>AC 2, AC>TC 2, TC>test 2, US>ticket 2, ticket>commit 2, US>docs 1, US>event 1"
assert_contains "$T_OUT" "traceability: 6 sources read, 0 missing, 2 commits, 1 test files, prefix PROJ inferred, 0 gaps in 0 classes"
assert_contains "$T_OUT" "Verdict: traced"
t_end

t_begin "the log can come on stdin"
d="$(tmpdir)/stdin"; fixture "$d"
T_IN="$(cat "$d/git.log")"
assert_exit 0 run "$d" --log -
T_IN=''
assert_contains "$T_OUT" "2 commits"
t_end

t_begin "REQ without story, story without AC and AC without TC are gaps"
d="$(tmpdir)/chain"; fixture "$d"
printf '| REQ-003 | Audit |\n' >> "$d/docs/product/PRD.md"
printf '\n### US-01-003 Audit trail\n\nTicket: PROJ-3\n' >> "$d/docs/product/backlog.md"
sed -i.bak '/TC-0002 | US-01-002/d' "$d/docs/testing/test-cases.md"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "problem: REQ without story: REQ-003 (fix: backlog)"
assert_contains "$T_OUT" "problem: story without AC: US-01-003"
assert_contains "$T_OUT" "problem: AC without TC: AC-US-01-002-1"
assert_contains "$T_OUT" "problem: ticket without commits: PROJ-3"
assert_contains "$T_OUT" "Verdict: not traced"
t_end

t_begin "TC without test, story without ticket, boundary without ADR, event not in sheet"
d="$(tmpdir)/links"; fixture "$d"
printf "it('TC-0001 signs in', () => {});\n" > "$d/src/app.test.ts"
sed -i.bak '/^Ticket: PROJ-1$/d' "$d/docs/product/backlog.md"
sed -i.bak 's/\[PROJ-1\] //' "$d/git.log"
printf '# ADR-0001 Add the CSV library\n' > "$d/docs/adr/0001-csv-library.md"
printf '| Event | Added in |\n| --- | --- |\n' > "$d/docs/analytics/EVENT_SHEET.md"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "problem: TC without test: TC-0002"
assert_contains "$T_OUT" "problem: story without ticket: US-01-001"
assert_contains "$T_OUT" "problem: boundary change without ADR: b2 (go.mod)"
assert_contains "$T_OUT" "problem: event not in sheet: login_done (US-01-001)"
t_end

t_begin "a missing source is its own gap and leaves its ids unlinked"
d="$(tmpdir)/missing"; fixture "$d"
rm "$d/docs/testing/test-cases.md"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "problem: missing source: missing docs/testing/test-cases.md: 2 AC could not be linked"
assert_contains "$T_OUT" "problem: AC without TC: AC-US-01-001-1"
assert_contains "$T_OUT" "1 missing"
t_end

t_begin "unknown tickets are counted; tracker none makes the ticket classes n/a"
d="$(tmpdir)/none"; fixture "$d"
printf '@@commit c3\n[PROJ-7] fix: typo\n\n@@files\n\nREADME.md\n' >> "$d/git.log"
assert_exit 0 run "$d" --prefix PROJ
assert_contains "$T_OUT" "Unknown tickets: 1 (PROJ-7)"
sed -i.bak '/^Ticket:/d' "$d/docs/product/backlog.md"
sed -i.bak 's/PROJ-2/US-01-002/' "$d/git.log" "$d/docs/adr/0001-csv-library.md"
assert_exit 0 run "$d" --tracker none
assert_contains "$T_OUT" "story without ticket n/a (tracker: none), ticket without commits n/a (tracker: none)"
t_end

t_begin "empty input fails: no ids and no commits"
d="$(tmpdir)/empty"; mkdir -p "$d"; : > "$d/git.log"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "0 ids and 0 commits read"
assert_contains "$T_OUT" "nothing checked"
t_end

t_summary
