# Test run: <branch> @ <sha>[+dirty]

<!-- Template guidance: the evidence of one test run on one commit: which
     suites ran, which did not and why, every failure at file:line with
     its TC and story, the slowest tests, flaky candidates and coverage.
     The developer reads it to fix failures, test-heal reads it to
     classify them, and a reviewer reads it to trust the pipeline. Every
     number comes from the runner's machine-readable output, never from a
     claim; a .json twin carries the same data. Delete each comment when
     you fill its section. -->

Date: <YYYY-MM-DD HH:MM> | Stack: <stack> | Selection: <all | --suite ... | --tag ... | --tc ... | --changed>
Raw output: `.scratch/test-run/<date>-<branch>/`

## Summary

<!-- What: the one summary line and the exit code.
     Good: passed, failed and skipped add up to run; coverage is a number
     read from a file or "coverage n/a"; the exit is 1 when any test failed
     or any selected suite did not run, and says both counts; a dirty tree
     shows +dirty in the header.
     Example: "tests: 151 run, 148 passed, 2 failed, 1 skipped, coverage
     71.2%" and "Exit: 1 (2 failures, 1 suite not run)". -->

```
tests: N run, P passed, F failed, S skipped, coverage C%
```

Exit: <0 | 1 (F failures, M suites not run)>

## Suites

<!-- What: one row per suite in the inventory, run or not, with the exact
     command used.
     Good: the command is the native runner with its machine-readable
     reporter (make -n shows it); a go package with no test files counts
     as zero tests; a suite that did not run says "not run (reason)" and
     never shows as skipped or passed. The rows below are examples.
     Example: | integration | go test | `go test -json ./internal/...` |
     64 | 64 | 0 | 0 | 38.5 s | run | -->

| Suite | Runner | Command | Tests | Passed | Failed | Skipped | Duration | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| unit | vitest | `pnpm exec vitest run --reporter=json` | 120 | 118 | 2 | 0 | 14.2 s | run |
| e2e | playwright | `pnpm exec playwright test --reporter=json` | 31 | 30 | 0 | 1 | 2 m 10 s | run |
| load | k6 | on demand | 0 | 0 | 0 | 0 | 0 | not run (on demand) |

A suite marked `not run` is not a pass. Reasons: runner missing, timed
out at <timeout>, on demand, refused (production host).

## Failures

<!-- What: one row per failed test (Gradle errors included), with the
     runner's own assertion message.
     Good: file:line points at the failing assertion, not the test file
     head; the TC id comes from the test name and the story from the case
     table, or "no case table"; the message is quoted, not paraphrased.
     Example: see the row below; "the login test broke" is the failure
     to avoid. -->

| Suite | Test | TC | Story | File:line | Assertion message |
| --- | --- | --- | --- | --- | --- |
| e2e | TC-0012 rejects an expired token | TC-0012 | US-01-003 | e2e/auth/login.spec.ts:41 | `getByRole('alert')` expected visible, received hidden |

Story from `docs/testing/test-cases.md` (or "no case table").

## Heal candidates and likely regressions

<!-- What: each failure sorted into a hint for test-heal: locator,
     timing or data (a heal candidate), or likely regression.
     Good: the Why names the runner signal: element not found, timeout
     waiting, strict mode violation, a 4xx from a fixture or a unique
     constraint for heal candidates; an expected value the product no
     longer produces for a regression. A hint, never a verdict.
     Example: | TC-0044 | data | unique constraint users_email_key from the
     seed fixture | -->

| Test | Hint | Why |
| --- | --- | --- |
| TC-0012 | locator | element not found, sibling with the same name exists |
| TC-0031 | likely regression | expected 423, received 200 |

Hints only. `test-heal` classifies each one with evidence.

## Slowest ten

<!-- What: the ten longest tests across all suites that ran, slowest first.
     Good: durations from the runner's report in one unit; the test name
     carries its TC id when it has one, so a slow case can be traced.
     Example: | TC-0102 checkout with three saved cards | e2e | 18.4 s | -->

| Test | Suite | Duration |
| --- | --- | --- |

## Flaky candidates

<!-- What: tests that passed after a retry in this run, or whose result
     differs from the last report on the same commit.
     Good: the evidence names the retry count or the earlier report file;
     a retried pass is listed even though the summary counts it passed,
     and retries are never raised to turn the summary green.
     Example: see the two rows below. -->

| Test | Evidence |
| --- | --- |
| TC-0007 | passed on retry 1 of 2 in this run |
| TC-0019 | failed in 2026-09-20-feature-TASK-142.json, passed now, same commit |

## Coverage

<!-- What: coverage per scope as the runner's summary file reports it.
     Good: every figure names its source file (coverage-summary.json,
     cov.json, jacoco XML, go test -cover lines); no file means "coverage
     n/a", never an estimate.
     Example: | internal/billing | 83.0% | cover.out (go test -cover) | -->

| Scope | Lines | Source file |
| --- | --- | --- |
| total | 71.2% | coverage/coverage-summary.json |

## Not run

<!-- What: every selected or present suite that did not run, and what
     would make it run.
     Good: the reason is one of runner missing, timed out (with the
     timeout), on demand or refused (production host); each one makes the
     exit non-zero when it was selected. Write "None." only when every
     suite in the inventory ran.
     Example: | load | refused (BASE_URL contains prod) | a staging BASE_URL
     and --suite load | -->

| Suite | Reason | What would run it |
| --- | --- | --- |
| ui | runner missing (xcodebuild) | a macOS runner |
