# Traceability matrix

<!-- Template guidance: the chain from each requirement down to its
     stories, criteria, test cases, tests, tickets, commits, docs and
     events, with every broken link named and the skill that fixes it. The
     tech lead reads it before a release sign-off; the product owner reads
     the gaps. Every count and gap is copied from trace_check.py output;
     a number the script did not print is not written, and the audited
     files are never edited. Delete each comment when you fill its
     section. -->

Built: <date>   Base ref: <ref>   Commits scanned: <n>
Verdict: traced | not traced (<K> gaps in <G> classes)

## 1. Sources

<!-- What: every source the skill looks for, read or missing, with the ids
     found in it.
     Good: a missing source says missing, never blank, and becomes a gap
     row in section 4; the git log row names the base ref it covered; the
     test files row lists the patterns searched; the tracker line says
     "tracker: none" rather than leaving tickets empty.
     Example: | docs/testing/test-cases.md | missing | 0 (all 41 ACs
     become "AC without TC") | -->

| Source | Status | Ids found |
| --- | --- | --- |
| docs/product/PRD.md | read / missing | REQ n |
| docs/product/backlog.md | | EP n, US n, AC n |
| docs/product/coverage.md | | |
| docs/testing/test-cases.md | | TC n |
| test files (<pattern list>) | | TC n, US n |
| git log <base>..HEAD | | tickets n, US n |
| docs/adr/ | | ADR n |
| docs/design/, docs/runbooks/ | | |
| docs/analytics/EVENT_SHEET.md | | events n |

## 2. Link counts

<!-- What: for each link in the chain, how many parents have at least one
     child, out of how many.
     Good: the numbers are the gate's Links line, not a recount; a link
     with no source reads 0 of n, not n/a, unless the tracker is none; US
     ids found in tests are a weaker link and are counted apart from TC
     ids.
     Example: | AC to TC | 38 | AC 41 | 93% | -->

| Link | Count | Of | Coverage |
| --- | --- | --- | --- |
| REQ to US | | REQ n | n% |
| US to AC | | US n | |
| AC to TC | | AC n | |
| TC to automated test | | TC n | |
| US to ticket (tracker: <name | none>) | | US n | |
| Ticket to commits | | tickets n | |
| US to docs (ADR, HLD, runbook) | | US n | |
| US to analytics events | | US n | |

## 3. Matrix

<!-- What: one row per REQ, following its links down to events; a REQ with
     several stories takes one row per story.
     Good: exact ids only, never "the login story"; an empty cell is a gap
     that also appears in section 4; the Test cell names the file; the
     Commits cell is a count. The row below is an example.
     Example: | REQ-007 | US-02-004 | AC-US-02-004-1 | TC-0031 |
     internal/auth/lockout_test.go | PROJ-188 | 4 | ADR-0006 |
     account_locked | -->

| REQ | US | AC | TC | Test | Ticket | Commits | Docs | Events |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| REQ-001 | US-00-001 | AC-US-00-001-1, -2 | TC-0001 | auth_test.go | PROJ-142 | 3 | ADR-0004 | otp_locked |

## 4. Gaps

<!-- What: every gap class with its count, the ids in it and the skill or
     action that closes it; then a row per missing source and the unknown
     tickets line.
     Good: counts and ids come from the gate's problem lines; a missing
     source reads "missing <path>: N <ids> could not be linked upward"
     with the skill that writes it; ticket classes read "n/a (tracker:
     none)" when no tracker is set; new routes added by hand to the
     boundary class say so; branch-only tickets carry "(from branches)".
     Example: | AC without TC | 3 | AC-US-02-004-2, AC-US-03-001-1,
     AC-US-03-001-4 | test-cases | -->

| Class | Count | Ids | Fix with |
| --- | --- | --- | --- |
| REQ without story | | | backlog |
| Story without AC | | | backlog |
| AC without TC | | | test-cases |
| TC without automated test | | | write the test, name it with the TC id |
| Story without ticket | | | create the ticket, add Ticket: to the story |
| Ticket without commits | | | start-task, commit with [<KEY>] (n/a when tracker: none) |
| Boundary change without ADR | | | adr |
| Event not in sheet | | | analytics-events |

Unknown tickets (in commits, in no story): <ids or none>
