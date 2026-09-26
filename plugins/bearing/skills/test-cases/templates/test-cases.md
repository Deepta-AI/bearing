# Test cases

<!-- Template guidance: the numbered case table every test carries by TC id.
     test-automation names each test after its row, test-run and
     test-heal report by it and traceability greps for it; testers
     and reviewers read it to see how each acceptance criterion is proved.
     cases_check.py parses the table, so keep the header row and its
     column names. The five rows below are examples: replace them.
     What: one row per case; every AC in the backlog has at least one live
     row, and an AC that takes input has a valid, a negative and a boundary
     row.
     Good: steps are numbered actions a stranger could follow; test data is
     literal ("a"*256, 0, -1, 2026-02-29), never "some invalid input";
     oracles are tagged checks that name the text, value or event (never
     "works" or "as expected"); a P1 row has two oracle categories, one of
     them not:. New ids continue from the highest; nothing is renumbered.
     Example: see TC-0002 below: the alert text, and two not: checks.
     Delete each comment when you fill its section. -->

Source: `<backlog path>` as of <YYYY-MM-DD>. Ids are permanent. A retired
case keeps its row with status `retired`; nothing is renumbered.

Type: `unit` (no I/O), `integration` (repository or route), `e2e` (user
flow), `manual` (judgement or a device). Priority: `P1` money, auth, data
loss; `P2` core flow; `P3` cosmetic. Automation: `planned`, `automated`,
`manual-only` (with the reason in the title), `retired`.

Oracles are designed after the rows, as tagged checks separated by `;`:
`ui:` what the user sees, `data:` persisted state read back, `not:` what
must not happen, `effect:` an event, message or log line, `inv:` an
invariant. Every row has one; a P1 row has two categories, one `not:`.

| TC | Story | ACs | Title | Preconditions | Steps | Test data | Expected result | Oracles | Type | Priority | Automation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |

<!-- Example rows, to show the shape; delete this comment and add real
     rows to the table above:
       | TC-0001 | US-01-001 | AC-US-01-001-1 | Valid login reaches the dashboard | A registered user exists | 1. Open /login 2. Enter email and password 3. Press Sign in | `user@example.test` / `correct-horse` | Dashboard heading visible; session cookie set | ui: heading "Dashboard" visible; data: GET /session returns the user; not: no role=alert | e2e | P1 | planned |
       | TC-0002 | US-01-001 | AC-US-01-001-1 | Wrong password is rejected | A registered user exists | 1. Open /login 2. Enter email and a wrong password 3. Press Sign in | `user@example.test` / `wrong` | "Email or password is incorrect" in a `role=alert`; no session cookie | ui: role=alert "Email or password is incorrect"; not: no session cookie; not: URL stays /login | e2e | P1 | planned |
       | TC-0003 | US-01-001 | AC-US-01-001-1 | Email at the length limit is accepted | none | 1. POST /auth/login with a 254-char email | `"a"*242 + "@example.test"` | 200 or 401, never 500 | data: status is 200 or 401; not: status 500 | integration | P2 | planned |
       | TC-0004 | US-01-001 | AC-US-01-001-1 | Email one past the limit is rejected | none | 1. POST /auth/login with a 255-char email | `"a"*243 + "@example.test"` | 422 with field `email` in the error details | data: 422, details[0].field is "email" | integration | P2 | planned |
       | TC-0005 | US-01-001 | AC-US-01-001-2 | Five failures lock the account | Counter at 4 | 1. POST /auth/login with a wrong password | `user@example.test` / `wrong` | 423, `otp_locked` event emitted once | data: 423 and the account row locked; effect: otp_locked emitted once; not: no sixth attempt counted | integration | P1 | planned |
-->
