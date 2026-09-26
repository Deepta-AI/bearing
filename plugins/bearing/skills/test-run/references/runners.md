# Runners: the exact command and report format per stack

One row per suite. The Makefile target tells you the suite exists
(`make -n <target>` shows its real command); the native command below is
what `test-run` executes, because it produces a file the skill can
parse. `<t>` is the timeout, `<out>` is
`.scratch/test-run/<date>-<branch>/<suite>`.

| Stack | Suite | Make target | Native command | Output |
| --- | --- | --- | --- | --- |
| Go | unit | `test` | `go test -json -race -count=1 -cover -timeout <t> ./... > <out>.jsonl` | JSON lines |
| Go | integration | `test-integration` | `DATABASE_URL=... go test -json -race -count=1 -tags=integration -timeout <t> ./internal/store/... > <out>.jsonl` | JSON lines |
| React | unit | `test` | `pnpm exec vitest run --reporter=json --outputFile=<out>.json --coverage --coverage.reporter=json-summary --testTimeout=<ms>` | JSON + `coverage/coverage-summary.json` |
| React | e2e | `test-e2e` | `PLAYWRIGHT_JSON_OUTPUT_NAME=<out>.json pnpm exec playwright test --reporter=json --global-timeout=<ms>` | JSON + `test-results/` traces |
| React Native | unit | `test` | `pnpm exec jest --ci --json --outputFile=<out>.json --coverage --coverageReporters=json-summary --testTimeout=<ms>` | JSON + `coverage/coverage-summary.json` |
| React Native | e2e | `test-e2e` | `maestro test --format junit --output <out>.xml .maestro` | JUnit XML + `~/.maestro/tests/` screenshots |
| Python | unit | `test` | `uv run pytest -m "not integration" --junitxml=<out>.xml --cov --cov-report=json:<out>-cov.json` | JUnit XML + coverage JSON |
| Python | integration | `test-integration` | `DATABASE_URL=... uv run pytest -m integration tests/integration --junitxml=<out>.xml` (add `--no-cov` only when pytest-cov is installed) | JUnit XML |
| Android | unit | `test` | `./gradlew testDebugUnitTest` | JUnit XML under `app/build/test-results/testDebugUnitTest/` |
| Android | ui | `test-ui` | `./gradlew connectedDebugAndroidTest` | JUnit XML under `app/build/outputs/androidTest-results/connected/` |
| iOS | unit | `test` | `swift test --parallel --xunit-output <out>.xml` | JUnit XML |
| iOS | ui | `test-ui` | `xcodebuild test -project <p> -scheme <s> -destination '<d>' -resultBundlePath build/TestResults.xcresult` | stdout lines + xcresult bundle |
| any | load | `load-test` | `k6 run --summary-export <out>.json -e STAGE=smoke -e BASE_URL=<url> tests/load/<flow>.js` | summary JSON |
| any | synthetic | `synthetic` | `make synthetic` (from `health-checks`) | JUnit XML when the target writes one, else exit code and the probe count on stdout |

## Python: choosing the command offline

The Python rows assume uv and pytest-cov; neither is guaranteed, and a
run must not reach the network. Pick the first that works and write the
command used in the report:

1. `uv.lock` or `[tool.uv]` present and `uv` on PATH: `uv run --offline pytest ...`.
   If uv cannot resolve offline, go to 2.
2. Otherwise `python3 -m pytest ...` (`.venv/bin/python -m pytest` when a
   `.venv` exists), after `python3 -c "import pytest"` succeeds.
3. Neither imports pytest: the runner command inside the Makefile `test`
   target (`make -n test`, often a `pytest` on PATH) with
   `--junitxml=<out>.xml` appended, and without any `|| true`, `; echo` or
   other part that swallows its exit code (SKILL.md step 1). No pytest
   anywhere: the suite is "not run (runner missing)".

`--cov` and `--cov-report` are added only when `python3 -c "import
pytest_cov"` succeeds; without it pytest stops on "unrecognized
arguments" before any test runs, which is not a test failure. The report
then says `coverage n/a (pytest-cov not installed)`. When the config's `addopts`
carries `--cov` options and `pytest_cov` does not import, override it
with `-o addopts=""` and pass back its other options by hand; the
"unrecognized arguments" exit (code 4) is a usage error that ran no test,
never a failure count and never a pass. `pythonpath` and
`testpaths` in `pytest.ini`, `pyproject.toml` or `setup.cfg` apply to
every variant; do not add `PYTHONPATH` by hand when they are set.

## Filters per runner

| Runner | `--tc TC-0231` | `--tag @P1` | one file |
| --- | --- | --- | --- |
| go test | `-run 'TC0231'` | build tag `-tags=P1` or `-run` on a name prefix | `./internal/auth/...` |
| vitest, jest | `-t 'TC-0231'` | `-t '@P1'` | the file path |
| playwright | `--grep 'TC-0231'` | `--grep '@P1'` | the spec path |
| pytest | `-k tc_0231` | `-m P1` | the file path |
| gradle | `--tests '*tc0231*'` | JUnit `@Tag("P1")` with a task filter | `--tests 'ClassName'` |
| swift test | `--filter 'TC0231'` | `--filter` on a name prefix | `--filter 'TargetName'` |
| xcodebuild | `-only-testing:UITests/<Class>/testTC0231...` | none; the name prefix | `-only-testing:UITests/<Class>` |
| maestro | the flow file whose line one is `# TC-0231` | `--include-tags P1` | the flow path |

## Timeouts

Go, vitest, jest and Playwright take the timeout on the command line.
pytest needs `pytest-timeout` (`--timeout=<s>`); without the plugin the
report says "no per-test timeout". Gradle, `swift test` and `xcodebuild`
have no run-level timeout flag; the report says so and the suite's
duration is the evidence. Maestro flows carry their own step timeouts.

## What to read from each format

- Go JSON lines: only events with a `Test` field. `Action` is `run`,
  `pass`, `fail` or `skip`; `Elapsed` is seconds; the `output` events
  before a `fail` hold the message and `file_test.go:NN:`. Package events
  with `Output` containing `coverage: NN.N% of statements` give coverage;
  `[no test files]` is zero tests.
- vitest and jest JSON: `numPassedTests`, `numFailedTests`,
  `numPendingTests` (skipped), `numTodoTests`; per test
  `testResults[].assertionResults[]` with `status`, `fullName`,
  `duration`, `failureMessages` (file:line in the stack); the file is
  `testResults[].name`. Coverage: `total.lines.pct` in
  `coverage-summary.json`.
- Playwright JSON: `stats.expected`, `unexpected`, `flaky`, `skipped`;
  walk `suites[]` recursively to `specs[].tests[].results[]` with
  `status`, `retry`, `duration`, `error.message`, and the spec's
  `file` and `line`. A test with more than one result whose last one
  passed is a flaky candidate.
- JUnit XML (pytest, gradle, swift test, maestro): `<testsuite tests
  failures errors skipped time>` and `<testcase classname name file line
  time>` with a `<failure message>` or `<error message>` child (both
  count as failed) or `<skipped>`. Gradle: one file per class, sum them.
- xcodebuild stdout: `Test Case '-[Target.Class testName]' passed (N
  seconds)` and `failed`; the failing assertion is the preceding
  `file.swift:NN: error:` line. The xcresult bundle is the evidence path.
- k6 summary JSON: `metrics.<name>.thresholds.<expr>.ok`; the suite
  passes only when every threshold is `ok`. Thresholds are the tests.
- Synthetic: each probe is one test; without JUnit output, the count of
  probes on stdout is the test count and the exit code is the result.

## TC and story ids

The TC id is in the test name in every stack: `TC-0012` (Playwright,
vitest, jest), `TestTC0012_` (Go), `test_tc_0012_` (pytest), `tc0012`
(Kotlin), `testTC0012` (Swift), `# TC-0012` on line one of a Maestro
flow. Normalise to `TC-0012` and look up the story in
`docs/testing/test-cases.md` (column `Story`).
