---
name: test-heal
description: 'Fixes failing or flaky tests: classifies each failure with evidence, heals locator, timing and data drift, leaves regressions red, quarantines flakes. Use when asked to "fix the flaky tests" or "heal the tests".'
argument-hint: "[report path, default the newest in docs/testing/reports/] [--tc TC-0231 | --suite e2e]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(make db:*), Bash(make migrate:*), Bash(make test-repeat:*), Bash(make test-visual-update:*), Bash(make check:*), Bash(make test:*), Bash(git diff:*), Bash(git log:*), Bash(git show:*), Bash(git status:*), Bash(go test:*), Bash(go vet:*), Bash(pnpm exec:*), Bash(pytest:*), Bash(python3 -m pytest:*), Bash(uv run pytest:*), Bash(./gradlew:*), Bash(swift test:*), Bash(xcodebuild test:*), Bash(maestro test:*), Bash(curl -fsS http://localhost:*), Bash(bash *bin/brg-state-path*)
---

# test-heal

A failing test is evidence. This skill decides what it is evidence of
before it changes anything, heals drift in the test, and never touches a
test that is right about a product that is wrong.

Not this: `test-run` finds the failures and hints at a class;
`test-automation` writes new tests; `test-cases` says what a
test must expect; this classifies with evidence and heals drift only.

## Inputs

- Report: `$1`; if absent, the newest `docs/testing/reports/*.json`; if absent, run the suites present (Makefile targets `test`, `test-integration`, `test-e2e`, `test-ui`, else the test folders) and take the failures from the runner output, running a shuffled or parallel suite several times, since one run shows only some of its flakes.
- Failure history: CI logs or run exports in the repository, the healing log, the report. From them take each test's observed failure rate p (failures over runs) and the conditions it failed under (shuffle, parallel, time of day, time zone, machine). Unknown p is said so.
- Failing test files: the report's file:line; else grep the test folders for the test name or the TC id.
- Traces: Playwright `test-results/`, Maestro `~/.maestro/tests/`, gradle `app/build/reports/androidTests/`, `build/TestResults.xcresult`; if absent, the runner's text output is the only evidence and the log row says so.
- Diff since the last green: `git log` and `git diff` from the commit of the last report with zero failures; else the base branch (`.bearing/state/<branch with / as _>.md`, printed by `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-state-path"`, its `Base:` line, else `origin/develop`, else `main`); always plus the working tree. `git show <commit>` for the change a failure started with.
- Helpers: `e2e/pages/`, `e2e/fixtures/`, `.maestro/screens/`, `tests/conftest.py`, `tests/factories/`, `internal/testutil/`; if absent, the fix lives in the test file and the report says the helper is missing.
- Server side: the request id or trace id in the failure or the trace, then the service logs CI keeps, the local Loki on `http://localhost:3100`, or an export the engineer pastes; if none, the evidence says "server side not read".
- Expected results: `docs/testing/test-cases.md` rows for the TC ids, and the stories and tasks the diff names; if absent, the test's own assertion is the expectation.
- Logs: `docs/testing/healing-log.md` and `docs/testing/quarantine.md`, appended to in their existing format; if absent, created from `templates/healing-log.md` and `templates/quarantine.md`.
- Reference: `references/classification.md` (classes, evidence, locator, timing and data rules).

## Steps

1. Load the failures, limited by `--tc` or `--suite`. Print "N failures
   examined" first. Zero failures: stop with "0 failures in <report>;
   nothing to heal" and exit non-zero.

2. Reproduce and classify each failure, one at a time, before any edit.
   Read the message, the trace, the rendered tree, the diff and the
   history; pick exactly one class from the reference and write the
   evidence line (a path, a diff line, a runner summary line).
   - Run it alone and in its suite, with the repeat command below, enough
     times to see it: at least 20, and at least 3/p when p is known (a 3%
     flake needs 100; 20 clean runs of it happen half the time and prove
     nothing). A fast test costs nothing at 500.
   - Reproduce under the conditions it failed in. Order flakes need the
     shuffle: Go prints `-test.shuffle <seed>` on a failing run, and
     `go test -shuffle=<seed>` replays that order every time; a pytest
     random-order plugin prints its seed the same way. Contention needs
     the suite's parallelism; date and clock flakes need the date or time
     zone pinned (`TZ=UTC`, an injected clock), because no amount of
     repetition moves the calendar.
   - Read the outcomes: fails alone some of the time is timing or data
     (random ids, shared names); never alone but in the suite is order
     or shared state (test data); every time is not flaky (drift, a time
     bomb date, or a regression); a wrong value is never timing.
   - A wrong value that varies between a few plausible answers is usually
     nondeterminism in the product: map or set iteration, a query without
     ORDER BY, goroutine or promise ordering, the wall clock in product
     code. Check the app diff for where it came in. That is a regression,
     however flaky it looks.

3. Heal by class, in the helper when the helper exists; the reference
   has the rules for each.
   - Locator drift: find the control by purpose in the rendered tree; role
     and accessible name, then label or placeholder, then a test id the
     story or element already names. Never a CSS class or path, XPath,
     `nth-child`, index, coordinate or an unnamed role. It must match
     exactly one element; strict mode stays on.
   - Copy drift: an expected string the product changed. Update it only
     when a story or task in the diff names the new copy (quote the
     criterion in the log); then the TC row that still states the old copy
     is stale, so update that row with the story id or report it for the
     owner, and say which document governs. Unnamed copy changes are
     regressions.
   - Timing: replace the sleep or raced assertion with a condition wait
     with a deadline (`expect(...).toBeVisible()`, `require.Eventually`,
     a poll on the observable result, a channel, `XCTestExpectation`).
     A test healed before by a longer sleep (see the log and `git log` on
     the file) gets the condition now, never another bump. Never raise a
     global timeout, and never slow or synchronise the product to suit a
     test.
   - Test data: make the data unique by construction (a counter, the test
     name, a run id), not a wider random range, which only lowers the
     rate; give each test its own state instead of a package-level shared
     one; replace fixed calendar dates with dates relative to an injected
     or current today. Never fix by ordering tests or turning the shuffle
     off. Assertions stay as specific as before (a count delta, not "no
     error").
   - Environment: the test is not edited. Start what a Makefile target
     provides (`make db`, `make migrate`), otherwise record the missing
     service, port or variable with the command that fixes it.
   - Visual change: only when a story or task names the new look and the
     row's other oracles hold; `make test-visual-update`, list the changed
     pngs for the engineer to commit alone with the story id. Tolerances
     and masks are never edited.
   - Real regression: the test is not changed, skipped, retried or
     quarantined. File it under Regressions with the TC id, the story id,
     the row's expected result, what the product did, the file:line and
     the commit it came in with, plus a reproduction that fails reliably
     (the failure count over N runs, or a command that forces the bad
     order). Product code is not this skill's to change: propose the fix
     in one line; if the engineer asked for it too, make it a separate,
     named product change.
   Shared drift (one page object locator, one builder behind several
   failures) is healed once in the helper and counted per failure.

4. Prove each heal on the same commit, with the runner's summary line.
   - Locator and copy drift, environment, visual: two runs in which the
     locator resolves to the one intended control. If the test then fails
     on its assertion, the heal stands: the drift was hiding a second
     failure. Classify that failure (step 2), usually a regression; never
     revert a correct locator heal because it unmasked one.
   - Timing and test data: consecutive passes, at least 50 and at least
     3/p (0 failures in N runs bounds the remaining rate below 3/N at 95%
     confidence), run under the conditions that reproduced it (shuffle,
     suite, parallelism), plus the step 2 reproduction showing it failed
     before. One failure is not healed: try the next class once, then
     quarantine (step 6).
   - Still bites: the healed test must still fail when the behaviour it
     guards breaks. Break it once by hand (drop the send, return the wrong
     count, restore the merged product when a fix was tried) and see the
     test fail by its deadline rather than hang or pass; then undo that
     edit and show with `git diff` that it is gone. A heal that makes the
     test pass whatever the product does is a hidden regression.
   Repeat commands: Go `go test -count=N -run '^<Test>$' <pkg>` (add
   `-shuffle=on`, or the failing seed, for order flakes; `-count` also
   defeats the test cache); Playwright `pnpm exec playwright test <spec>
   -g "<TC id>" --repeat-each=N --workers=4`; pytest with pytest-repeat
   installed `pytest <file>::<test> --count=N`, otherwise the offline loop
   `for i in $(seq N); do pytest -q -p no:cacheprovider <file>::<test> >/dev/null || echo fail; done | grep -c fail`
   (the count of failures in N; never download a plugin for this); XCUITest `xcodebuild test
   -only-testing:<target>/<test> -test-iterations N
   -run-tests-until-failure`. Maestro and Espresso: the repository's
   `make test-repeat` when it exists, else the heal is provisional
   ("repeat proof not run") and counted apart from healed.

5. Run each affected suite once more as the gate runs it (`make check` or
   the CI script's command, shuffle included), and the linters it runs
   (`go vet ./...`). A test that passed before and fails now means a heal
   broke it: revert that heal and count the test as not healed. Failures
   the heals unmasked are regressions from step 3, not new failures.

6. Quarantine only a test that could not be healed and is flaky: the
   stack's tag (`@quarantine`, `@pytest.mark.quarantine`,
   `//go:build !quarantine`, Maestro `tags: [quarantine]`), a task id and
   a deadline (14 days unless given) in a comment above it, a row in
   `docs/testing/quarantine.md`, excluded from the CI job, still run
   nightly. Never delete. Never quarantine a regression.

7. Append one row per failure examined to `docs/testing/healing-log.md`
   in its existing columns. Nothing is committed; the changes stay in the
   working tree for the engineer.

## Output contract

```
## Test heal: <report> (N failures examined)
| Test | TC | Class | Evidence | Change | Proof |
...
Healed: H (locator L, copy C, timing T, data D)   Provisional: P
Proof: <per heal: runs, conditions, runner line; still-bites check>
Suite: <gate command> N tests, F failing (<which, and why>)
Quarantined: Q (task <id>, until <date>)   Environment: E   Regressions: R
Regressions:
  TC-nnnn US-nn-nnn  expected <row>; product does <...>  (<file:line>, <commit>)  repro: <command, k of N failed>
Ready to ship: no while R > 0 (a green suite with a regression left is not claimed)
Retries: <CI retry count>; not raised; <recommendation once the flakes are healed>
Files: <changed test, helper and log files>
```

## Gotchas

- A CI retry loop is how flakes hide regressions. Never add one or raise
  its count; recommend lowering it once the flakes are healed.
- Weakening an assertion hides a regression: `toBeVisible` to
  `toBeAttached`, exact to substring, `423` to "not 500", a status range,
  asserting what the code does instead of what the row says. The one
  allowed expected-value change is copy a story names.
- A test healed twice in a month is a quarantine candidate even when green
  today; say so in the log.
- The test name is the traceability link: healing never renames a test or
  moves its TC id.
- "It works now" is not evidence. Each row carries a path, a diff line or
  the runner's count.
