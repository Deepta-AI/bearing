# Healing log

<!-- Template guidance: the append-only record of every failing test
     test-heal examined and what it did about it. The developer and the
     reviewer read it to trust a heal, and the next heal run reads it to
     spot a test healed twice in a month. The rows below are examples:
     replace them.
     What: one row per failure examined, healed or not, in the order
     examined.
     Good: exactly one class per row; the evidence is a path, a diff line,
     a screenshot or the runner's own repeat line, never "fixed" or "works
     now"; the proof is 2/2 for locator and environment, at least 50 and
     at least 3/p consecutive passes for timing and data, or "provisional (repeat proof not run)"; a regression row
     has Change "none" and re-runs "not run"; no row weakens an assertion
     or renames a test.
     Example: see the TC-0019 row: the 20-run reproduction, the wait that
     replaced the sleep, and "50/50: 50 passed".
     Delete each comment when you fill its section. -->

One row per failure `test-heal` examined, newest at the bottom. Ids
are the test-case ids from `docs/testing/test-cases.md`. Evidence is a
path, a diff line, a screenshot or a retry count; a bare "fixed" is not a
row. A regression row has no change and a re-run of `not run`.

Classes: `locator` (element exists with a different role, name, test id
or structure), `timing` (passes with a proper wait), `data` (a fixture or
builder no longer valid), `environment` (a missing service, port or
variable), `visual` (a screenshot diff a story or task asked for; the new
baseline is committed on its own), `regression` (the assertion is right,
the product is wrong).

| Date | Test | TC | Story | Class | Evidence | Change | Proof (runner line: 2/2 or 50/50, or provisional) | Suite re-run |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |

<!-- Example rows, to show the shape; delete this comment and add real
     rows to the table above:
       | 2026-09-22 | TC-0012 rejects an expired token | TC-0012 | US-01-003 | locator | trace: test-results/tc-0012/trace.zip; app diff: src/features/auth/LoginForm.tsx:41 renamed the alert | e2e/pages/login.page.ts: `getByText("Error")` to `getByRole("alert")` | 2/2 pass | e2e 31 tests, 0 new failures |
       | 2026-09-22 | TC-0019 lists the newest order first | TC-0019 | US-04-002 | timing | alone, `--repeat-each=20`: "14 passed, 6 failed"; assertion raced the list fetch | e2e/pages/orders.page.ts: `waitForTimeout(500)` to `expect(rows.first()).toBeVisible()` | 50/50: "50 passed" | e2e 31 tests, 0 new failures |
       | 2026-09-22 | test_tc_0044_expired_coupon | TC-0044 | US-06-001 | data | fixture `coupon_expired` had `expires_at` fixed at 2025-12-31 while the test clock is injected at 2025-12-01, so the coupon was still valid | tests/factories/coupon.py: expiry from the injected clock minus one day | 2/2 pass | integration 58 tests, 0 new failures |
       | 2026-09-22 | TestTC0031_LocksAfterFiveFailures | TC-0031 | US-01-005 | regression | expected 423 (row TC-0031); product returned 200; app diff: internal/auth/service.go:88 removed the counter check | none | not run | not run |
       | 2026-09-22 | TC-0007 uploads an avatar | TC-0007 | US-02-004 | environment | `ECONNREFUSED 127.0.0.1:9000`; MinIO not started; `make dev` starts it | none (documented) | 2/2 pass after `make dev` | e2e 31 tests, 0 new failures |
-->
