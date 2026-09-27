---
name: test-run
description: 'Runs every test suite present into one report: failures at file:line, slowest, flaky, coverage; a suite that did not run never passes. Use when asked to "run the tests", "what is failing" or "run TC-0231".'
argument-hint: "[--suite unit|integration|e2e|matrix|visual|ui|load|synthetic] [--tag @P1] [--tc TC-0231] [--changed] [--timeout 20m]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(make -n:*), Bash(make synthetic:*), Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git rev-parse:*), Bash(git merge-base:*), Bash(git rev-list:*), Bash(git worktree:*), Bash(git archive:*), Bash(go test:*), Bash(pnpm exec:*), Bash(uv run pytest:*), Bash(uv run --offline pytest:*), Bash(python3 -m pytest:*), Bash(pytest:*), Bash(.venv/bin/python -m pytest:*), Bash(python3 -c:*), Bash(./gradlew:*), Bash(swift test:*), Bash(xcodebuild test:*), Bash(maestro test:*), Bash(k6 run:*), Bash(bash *bin/brg-state-path*)
---

# test-run

A green pipeline says nothing about which tests ran. This skill runs every
suite the repository has, parses the runner's own machine-readable output,
and writes one report that names each test, each failure and each suite
that never started. A suite that did not run is never a pass.

Not this: `test-automation` builds suites and writes tests;
`test-heal` classifies and fixes failures; `test-cases` derives
the table; this only runs what exists and reports.

## Inputs

- Stack: looks in the Makefile and `stack.json`; if absent, detects from `package.json` (react, expo), `go.mod`, `pyproject.toml`, `build.gradle.kts`, `Package.swift` or `project.yml`. None of these: stop with "provide a repository with a package manifest".
- Suites: looks in the Makefile targets `test`, `test-integration`, `test-e2e`, `test-e2e-matrix` (matrix), `test-visual` (visual), `test-ui`, `load-test`, `synthetic` (`make -n <target>` shows the real command); if absent, the test folders (`*_test.go`, `tests/`, `tests/integration/`, `e2e/`, `.maestro/`, `androidTest/`, `UITests/`, `tests/load/`, `tests/synthetic/`).
- Selection: `$ARGUMENTS` as in the hint; if absent, every suite present except `matrix`, `load` and `synthetic`, which run only when named with `--suite` (the matrix repeats e2e on every browser and phone; CI runs it after merge).
- Base for `--changed`: looks in `.bearing/state/<branch with / as _>.md` (`bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-state-path"` prints it) (`Base:` line); if absent, every one of `origin/develop`, `develop`, `origin/main`, `main`, `origin/master`, `master` that `git rev-parse --verify` finds is a candidate, and the base is the candidate whose merge base with HEAD leaves the fewest branch commits (`git rev-list --count <merge-base>..HEAD`), develop before main on a tie. The diff is `git diff <merge-base>` so commits that landed on the base after the branch point are not the branch's; the working tree diff is always included. Print the base and why it was chosen.
- Case table: `docs/testing/test-cases.md` for the TC to story map; if absent, the story column says "no case table" (the table comes from `test-cases`).
- Earlier reports: `docs/testing/reports/*.json` for flaky candidates across runs; if absent, flaky candidates come from retries in this run only.
- Production host for `--suite load`: `.gitlab-ci.yml` `deploy-production` environment; if absent, the `prod` substring in `BASE_URL`. A match refuses the suite.
- Templates and references in this skill's folder: `templates/report.md`, `references/runners.md`.

## Steps

1. Detect the stack and inventory the suites as in Inputs. Print the
   inventory (suite, runner, command, present or absent) before running
   anything. Zero suites: stop with "0 suites found: no Makefile test
   target and no test folder" and exit non-zero. For each Makefile target
   and each CI job that runs one, read the recipe from `make -n` and the
   Makefile text for anything that swallows a failure: `|| true`, `|| :`,
   `; true`, `; echo ...` after the runner, a `-` recipe prefix,
   `set +e`, `.IGNORE`, `--exit-zero`, or output piped (`| tee`, `| tail`)
   without `pipefail`. Each one goes in the report as "target <name>
   exits 0 on failure (<file:line>)": that is why a pipeline can be green
   over failing tests. Never take a result from such a target; run the
   native command.
2. Resolve the selection. `--suite` limits the suites; `--tag` and `--tc`
   become the runner's own filter from `references/runners.md` (`--grep`,
   `-run`, `-k`, `-m`, `--tests`, `--filter`, `--include-tags`);
   `--changed` selects tests whose file is in the diff, tests in the
   feature folder of a changed source file, and tests named with a TC id
   whose row changed in the case table. Zero tests selected: report the
   diff files and exit non-zero.
3. Run each selected suite with the native command and reporter from
   `references/runners.md`, raw output under
   `.scratch/test-run/<date>-<branch>/<suite>.<ext>`, the timeout from
   `--timeout` (default 20 minutes per suite) passed through the runner's
   own flag. Check the runner offline first (the Python fallbacks are in
   `references/runners.md`: `uv run --offline`, then `python3 -m pytest`,
   and `--cov` only when `pytest_cov` imports); a plugin or network the
   command needs and cannot get is a changed command, noted in the report,
   not a missing suite. A missing binary marks the suite "not run (runner missing)";
   a timeout marks it "not run (timed out)" and keeps the results seen;
   the other suites still run. Load and synthetic suites run the
   production check from Inputs first.
4. Parse every raw file into one model per test: suite, name, file:line,
   status, duration, retries, message. Extract `TC-nnnn` from the name;
   look up the story id in the case table. A suite in which every test
   skipped itself for a missing precondition (`DATABASE_URL not set`, an
   `importorskip`, no device) is "not run (<reason>)": it examined nothing.
   Its tests stay out of the headline counts, which cover run suites only,
   so the headline and the per-suite table agree.
5. Compute the summary counts, the per-suite table, the failures with the
   assertion message and file:line, the slowest ten, the flaky candidates
   (passed after a retry in this run, or a different result from the last
   report on the same commit), and coverage from the runner's summary
   file when present.
6. Quarantine: when `docs/testing/quarantine.md` exists, every row with
   an empty Released cell and a Deadline before today goes at the top of
   the report as "overdue quarantine: <test> (TC, task, deadline)" and
   into the summary as a count; the run fails on any overdue row, so a
   quarantine cannot outlive its deadline silently.
7. Read what the runner cannot tell you. The counts say what ran; a
   senior engineer also says what the green and the skipped parts prove.
   - Every skipped or quarantined test on the code in question: run it
     with the skip disabled (pytest: `-p no:skipping` with the test's node
     id ignores skip marks; Go, vitest, others: a `git worktree` copy
     under `.scratch/` with the skip line removed). Report "still fails
     (<message>)" or "passes on this code: the skip can be released".
     Never un-skip in the user's tree.
   - Every test that did not run (no database, no device): read its body
     and fixtures and say what it would prove if it ran. A body that only
     calls `t.Fatal`, `pass` or asserts nothing is a placeholder, not a
     pending check. Tests that write the same keys on a connection that
     commits depend on order and on a clean database. SQL the code under
     test relies on (`ON CONFLICT (cols)` needs a unique index on exactly
     those columns, a foreign key, a column) is checked against the
     migrations or schema in the repository; a missing one means the
     test fails even with a database.
   - When the user names a symptom ("late fees look wrong", "totals are
     off by a paisa"), a failing test near it is a lead, not the answer.
     Read the code path, and when the user or a document gives an example
     (amount, date, expected value), compute it through the code by hand
     or with a one-line call and say which defect produces that number.
     Look at the boundaries no test pins (the first day after a grace
     period, a month or rounding step, a half-paisa) and at comments,
     docs or constants that disagree. Label each finding "not covered by
     any test", never as a test result.
   - A failure where the code and the test (or case table) disagree and
     a comment defends the code ("raised with the pricing change") is a
     decision for the user: name both values and the source behind each;
     do not call either one the bug.
8. Write `docs/testing/reports/<date>-<branch>.md` from
   `templates/report.md` (slashes in the branch become `-`) and the same
   data as `docs/testing/reports/<date>-<branch>.json`. Print the summary
   line. Exit non-zero when any test failed or any selected suite did not
   run.
9. Sort the failures into hints: "element not found", "timeout waiting",
   "strict mode violation", a 4xx from a fixture or a unique constraint
   are heal candidates for `test-heal`; a screenshot mismatch is a
   visual candidate, and a failure on one browser or phone of the matrix
   only is reported with that project's name; an assertion on an expected
   value the product no longer produces is a likely regression. This is a
   hint, not a classification; `test-heal` classifies with evidence.

## Output contract

```
## Test run: <branch> @ <sha>[+dirty] (<stack>)
Suites: N present, R run, M not run (<suite>: runner missing | on demand | timed out | refused)
tests: N run, P passed, F failed, S skipped, coverage C%
Per suite: unit P/F/S  integration P/F/S  e2e P/F/S
Failures:
  <suite>  <test name>  TC-nnnn  US-nn-nnn  <file:line>  <assertion message>
Heal candidates: K (<test>: locator | timing | data | visual)   Likely regressions: J
Flaky candidates: Q   Slowest: <test> <s>, ...
Quarantine: N rows, K overdue (<test> past <deadline>, ...) | no quarantine file
Not proven: <each skipped, not-run or placeholder test and what it leaves unverified>
Beyond the tests: <each defect found by reading or computing, "not covered by any test">
Commands: <every command run, in full with its files and flags, so the user can repeat it>
Report: docs/testing/reports/<date>-<branch>.md (+ .json)
```

The final message is the deliverable; the report file is the archive.
Everything the user needs to act (each failure's full test name,
file:line and got/want values, the base for `--changed`, the commands)
is in the message itself, not only in the report or the working log.
Readiness: never call a branch good or ready while a test fails, a
selected suite did not run, or part of the change is covered only by
tests that did not run; say what must happen first.

## Gotchas

- A missing runner, a timeout or a refused suite is "not run" and makes
  the exit code non-zero. Reporting it as skipped hides an empty gate.
- `go test -json` prints one Action line per event; a package with
  `[no test files]` is zero tests, not a pass. Sum only `Test` events.
- Playwright retries count a test as passed on its final result; the
  retried test is still listed as a flaky candidate. Never raise
  `retries` to make the summary line green.
- vitest and jest `numTotalTests` include skipped and todo; the summary
  counts passed, failed and skipped separately so they add up.
- Gradle writes one XML per class; sum the `tests`, `failures`, `errors`
  and `skipped` attributes. `errors` are failures in the report.
- Coverage is read from a file (`coverage-summary.json`, `cov.json`,
  jacoco XML, the `go test -cover` lines), never from a claim. Absent:
  `coverage n/a`.
- Load and synthetic suites never run against production and never run
  unnamed; `load-test` owns the thresholds, this skill only runs them.
- The report is evidence for its commit only. A dirty tree is marked
  `+dirty` in the header and the summary line. To compare with the
  committed state, run the suite on a `git worktree add` or `git archive
  HEAD` copy under `.scratch/`; never stash, reset or check out over the
  user's working tree.
