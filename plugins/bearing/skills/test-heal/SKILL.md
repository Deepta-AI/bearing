---
name: test-heal
description: 'Fixes failing or flaky tests: classifies each failure with evidence, heals locator, timing and data drift, leaves regressions red, quarantines flakes. Use when asked to "fix the flaky tests" or "heal the tests".'
argument-hint: "[report path, default the newest in docs/testing/reports/] [--tc TC-0231 | --suite e2e]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(make db:*), Bash(make migrate:*), Bash(make test-repeat:*), Bash(make test-visual-update:*), Bash(git diff:*), Bash(git log:*), Bash(go test:*), Bash(pnpm exec:*), Bash(uv run pytest:*), Bash(uv run --with pytest-repeat==0.9.4 pytest:*), Bash(./gradlew:*), Bash(swift test:*), Bash(xcodebuild test:*), Bash(maestro test:*), Bash(curl -fsS http://localhost:*), Bash(bash *bin/brg-state-path*)
---

# test-heal

A failing test is evidence. This skill decides what it is evidence of
before it changes anything, heals the five kinds of drift, and never
touches a test that is right about a product that is wrong.

Not this: `test-run` finds the failures and hints at a class;
`test-automation` writes new tests; `test-cases` says what a
test must expect; this classifies with evidence and heals drift only.

## Inputs

- Report: `$1`; if absent, the newest `docs/testing/reports/*.json`; if absent, runs the suites present (Makefile targets `test`, `test-integration`, `test-e2e`, `test-ui`, else the test folders) and takes the failures from the runner output (the fuller report comes from `test-run`).
- Failing test files: the report's file:line; if absent, grep the test folders for the test name or the TC id.
- Traces: Playwright `test-results/`, Maestro `~/.maestro/tests/`, gradle `app/build/reports/androidTests/`, `build/TestResults.xcresult`; if absent, the runner's text output is the only evidence and the log row says so.
- Diff since the last green: `git diff` against the commit of the last report with zero failures; if absent, the base branch (`.bearing/state/<branch with / as _>.md` (`bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-state-path"` prints it), its `Base:` line, else `origin/develop`, else `main`); always plus the working tree.
- Helpers: `e2e/pages/`, `e2e/fixtures/`, `.maestro/screens/`, `tests/conftest.py`, `tests/factories/`, `internal/testutil/`; if absent, the fix lives in the test file and the report says the helper is missing.
- Server side: the request id or trace id in the failure message or the
  trace, then the service logs the CI job keeps, the local Loki on
  `http://localhost:3100` from `observability`, or an export the
  engineer pastes from Grafana, Datadog or Sentry; if none, the evidence
  line says "server side not read".
- Expected results: `docs/testing/test-cases.md` rows for the TC ids; if absent, the test's own assertion is the expectation.
- Logs: `docs/testing/healing-log.md` and `docs/testing/quarantine.md`, appended to; if absent, created from `templates/healing-log.md` and `templates/quarantine.md`.
- Reference in this skill's folder: `references/classification.md`.

## Steps

1. Load the failures, limited by `--tc` or `--suite`. Print "N failures
   examined" first. Zero failures: stop with "0 failures in <report>;
   nothing to heal" and exit non-zero.
2. For each failure, one at a time: read the message, the trace, the
   rendered tree and the diff, then pick exactly one class from
   `references/classification.md` and write the evidence line (a path, a
   diff line, a screenshot, a retry result). Two classes fit: read again.
   Still unclear: real regression. Before calling a failure timing or
   flaky, reproduce it: run it alone 20 times with the repeat command
   below. It never fails alone but fails in the suite: order or data
   dependency (a test data heal). It fails alone some of the time:
   timing. It fails every time: not flaky; drift or a regression. The
   runner's own summary line ("17 passed, 3 failed") is the evidence.
3. Heal by class, in the helper when the helper exists:
   - Locator drift: find the control by purpose in the rendered tree.
     Role and accessible name first, then label or placeholder, then a
     test id already on the element. Never a CSS path, XPath,
     `nth-child`, index or coordinate. No stable handle: the fix is an
     accessible name or test id in the app, with the TC id in the commit.
   - Timing: replace the sleep or the raced assertion with the framework's
     condition (`expect(...).toBeVisible()`, `extendedWaitUntil`,
     `waitUntilExactlyOneExists`, `XCTestExpectation`, a polling
     `assertEventually`). Never raise a global timeout.
   - Test data: repair the builder or fixture so it creates what it
     assumes and is unique per run (run id, injected clock). Never fix by
     ordering tests.
   - Environment: the test is not edited. Start what a Makefile target
     provides (`make db`, `make migrate`), otherwise record the missing
     service, port or variable under Environment with the command that
     fixes it.
   - Visual change: only when a story or task names the new look and the
     row's other oracles still hold. Run `make test-visual-update` and list
     the changed pngs for the engineer to commit on their own with the
     story id; the heal never edits the spec's tolerance or masks.
   - Real regression: nothing changes. File it under Regressions with the
     TC id, the story id, the row's expected result, what the product did
     and the file:line.
   Shared drift (one page object locator, one builder behind several
   failures) is healed once in the helper and counted per failure.
4. Prove each heal on the same commit, with the runner's summary line
   as evidence:
   - Locator drift, environment and visual change: two passes.
   - Timing and test data: 50 passes of 50 with the repeat command, and
     the 20-run reproduction from step 2 showing it failed before. One
     failure in 50 is not healed: try the next class once; still
     failing, quarantine (step 6).
   Repeat commands: Playwright `pnpm exec playwright test <spec> -g
   "<TC id>" --repeat-each=50 --workers=4`; pytest `uv run --with
   pytest-repeat==0.9.4 pytest <file>::<test> --count=50`; Go `go test -run
   '^<Test>$' -count=50 <pkg>`; XCUITest `xcodebuild test
   -only-testing:<target>/<test> -test-iterations 50
   -run-tests-until-failure`. Maestro and Espresso have no repeat flag:
   use the repository's `make test-repeat` target when it exists, else
   the heal is recorded as provisional ("repeat proof not run") and
   counted apart from healed.
5. Run the whole suite each healed test belongs to, once. A new failure
   means the heal broke something: revert that heal, report it, count the
   test as not healed.
6. Quarantine only a test that could not be healed and is flaky: the
   stack's tag (`@quarantine`, `@pytest.mark.quarantine`,
   `//go:build !quarantine`, Maestro `tags: [quarantine]`), a task id and
   a deadline (14 days unless given) in the comment above it, a row in
   `docs/testing/quarantine.md`, excluded from the CI job and still run
   nightly. Never delete. Never quarantine a regression.
7. Append one row per failure examined to `docs/testing/healing-log.md`
   and print the counts and the file list.

## Output contract

```
## Test heal: <report> (N failures examined)
| Test | TC | Class | Evidence | Change | Re-run |
...
Healed: H (locator L, timing T, data D)   Provisional: P (no repeat flag)
Proof: locator and environment 2/2 each; timing and data 50/50 each (runner lines in the log)
Suite re-run: <suite> N tests, 0 new failures
Quarantined: Q (task <id>, until <date>)   Environment: E   Regressions: R
Regressions:
  TC-nnnn US-nn-nnn  expected <row's expected result>; product did <...>  (<file:line>)
Files: docs/testing/healing-log.md, docs/testing/quarantine.md, <changed test and helper files>
```

## Gotchas

- A flake fix proven by two passes is proven by luck. A test that fails
  one run in ten passes twice in a row four times out of five; 50 of 50
  is the bar for timing and data heals.
- A heal without its proof is not a heal; it is counted as not healed
  and said so.
- Weakening the assertion is hiding a regression: `toBeVisible` to
  `toBeAttached`, exact to substring, `423` to "not 500", or a raised
  `retries`. Locators change, waits change, expectations do not.
- A locator that matches two elements is not healed. Strict mode stays
  on; the fix names one control.
- A test that only passes after a hand-started service is an environment
  finding for the Makefile, not a pass.
- A test healed twice in a month is a quarantine candidate even when it
  is green today; say so in the log.
- The test name is the traceability link. Healing never renames a test
  or moves its TC id.
- "It works now" is not evidence. Each log row carries a path, a diff
  line, a screenshot or a retry count.
