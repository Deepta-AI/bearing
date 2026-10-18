# Runners: the exact command and report format per stack

One row per suite. When the repository's Makefile has the suite's
target (`test`, `test-integration`, `test-e2e`, `test-ui`, `test-visual`,
`test-e2e-matrix`), `test-run` runs `make <target>` and reads the report
file the recipe writes (`make -n <target>` shows it), else the runner's
summary on stdout. A target that swallows a failure (SKILL.md step 1), or
no target at all, means the native command below, which writes a file
the skill can parse. The load suite always runs its k6 command. `<t>` is the timeout, `<out>` is
`.scratch/test-run/<date>-<branch>/<suite>`.

| Stack | Suite | Make target (runs when present) | Native command (no target, or one that swallows a failure) | Output |
| --- | --- | --- | --- | --- |
| Go | unit | `test` | `go test -json -race -count=1 -cover -timeout <t> ./... > <out>.jsonl` | JSON lines |
| Go | integration | `test-integration` | `DATABASE_URL=... go test -json -race -count=1 -tags=integration -timeout <t> ./internal/store/... > <out>.jsonl` | JSON lines |
| React | unit | `test` | `pnpm exec vitest run --reporter=json --outputFile=<out>.json --coverage --coverage.reporter=json-summary --testTimeout=<ms>` | JSON + `coverage/coverage-summary.json` |
| React | e2e | `test-e2e` | `PLAYWRIGHT_JSON_OUTPUT_NAME=<out>.json pnpm exec playwright test --reporter=json --global-timeout=<ms>` | JSON + `test-results/` traces |
| React | visual | `test-visual` | `PLAYWRIGHT_JSON_OUTPUT_NAME=<out>.json pnpm exec playwright test e2e/visual --reporter=json --global-timeout=<ms>` | JSON + diff images under `test-results/` |
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

## Layers and scoped selection

`--changed` (scope changed) maps the diff to layers and runs the suites of
those layers. The layers and their suites:

| Layer | Suites (Makefile target) |
| --- | --- |
| `unit` | `test` |
| `api` | `test-integration` (responses checked against `api/openapi.yaml` where `test-automation` wired it) |
| `ui` | `test-e2e` (Playwright, Maestro), `test-ui` (Android, iOS) |
| `visual` | `test-visual` |

A layer whose suite the repository lacks is printed "api: no integration
suite here"; the suite is absent, not unrun, and is not counted. Scope
full is every suite present (a regression is scope full plus `matrix` at
a release); the matrix replaces `e2e` when selected.

### The call and what its result means

`bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-changed" --layers --base <base>`
prints `<layer>\t<file>` lines, then
`brg-changed: <N> files, layers: <list|none>[ (toolchain changed: <file>)]`.
Skip the `none` lines. Read the exit code and the counts line together:

| Result | Meaning | What the run does |
| --- | --- | --- |
| exit 0, counts line, layers listed | normal | run the listed layers; a toolchain change lists all four |
| exit 0, counts line, `layers: none` | documentation only, N files | write the evidence with `layers: []` and `files: N`, print "0 layers touched by N changed files: nothing to test", exit non-zero |
| exit 1, `0 files changed against <base>` or `against the working tree` | nothing changed | print it, exit non-zero, no suite runs |
| exit 1, any other line (`base ... does not resolve`, `has no merge base`) | an error | quote the line, exit non-zero, no suite runs; never fall back to the whole tree |
| exit 0, no `brg-changed:` counts line | an older copy that ignores `--layers` and prints plain file names | say "brg-changed lacks --layers" in the report, select as before over every suite present |

Deleted files count as changed. The flag is detected from the counts line,
never from the exit code alone: an old copy exits 0 on any flag.

### Inside a layer

Within a selected suite run the test files in the diff, test files in the
feature folder of a changed source file, and tests naming a TC whose row
changed in the case table. When that selects zero tests in a layer the
diff touched, run the whole suite: a touched layer never runs zero tests.
The `visual` layer always runs the whole visual suite, since a shared
style or token reaches every screen.

### Unit reuse

When `.bearing/state/.check-changed-passed` or `.bearing/state/.check-passed`
is newer than every changed file, the unit suite is not rerun. The report
says `unit: covered by make check-changed at <time>`, status `covered`,
with the counts that target printed when it printed them, else
`unit: covered, counts n/a`. Reuse needs both: the marker is newer than
every changed file now, and no file changed after it. The autopilot gate
checks the same mtimes again, so a stale claim fails there.

### The evidence file

Every run writes `.scratch/test-run/<branch>-<scope>.json`, overwriting the
last, with the branch from `git branch --show-current` and `/` turned into
`_` (empty output is a detached HEAD: stop, "detached HEAD: no branch name
for the evidence file"). It is a superset of the report JSON, so
`test-heal` can read it:

```json
{"scope": "changed", "sha": "<HEAD>", "dirty": false, "base": "origin/develop",
 "files": 3, "layers": ["unit", "ui", "visual"], "except": [],
 "suites": [{"name": "e2e", "status": "run", "reason": "", "passed": 4, "failed": 0, "skipped": 0}],
 "tests": 9, "failed": 0, "not_run": ["integration"],
 "failures": [{"suite": "e2e", "test": "TC-0012 rejects an expired token", "tc": "TC-0012",
   "file": "e2e/auth/login.spec.ts", "line": 41, "message": "expected visible, received hidden"}]}
```

`status` is `run`, `covered` or `not run`. `reason` is `""` for `run`;
`covered by make check-changed` or `covered by make check` for `covered`;
for `not run` one of `runner missing`, `timed out`, `on demand`,
`refused`, `no database`, `0 tests` (a suite that examined zero tests),
or `precondition: <text>` (every test skipped itself, as
`precondition: DATABASE_URL not set`). `not_run` lists the selected suites that did not run, each
with its reason in `suites`. `tests` and `failed` count only suites with
status `run`. A `covered` suite carries `name`, `status`, `reason`,
`marker` (the marker file's path) and `passed`, `failed`, `skipped` as
the target printed them, each `null` when it printed none. In `failures`,
`line` is an integer, `null` when the runner gives none. Scope full has
`files` `null` (no diff is taken), `layers` and `base` empty and `except`
as given. Counts line: `S` is the suites with status `run` or `covered`,
`P` the suites selected and present, `N` the suites not run.

When unit is the only suite, `--except unit` selects none and writes no
evidence, so definition of done item 14 writes the full file itself:

```json
{"scope": "full", "sha": "<HEAD>", "dirty": false, "files": null,
 "layers": [], "base": "", "except": ["unit"], "suites": [], "tests": 0,
 "failed": 0, "not_run": [], "failures": [], "n_a": "no suite beyond unit"}
```

`n_a` appears only there; the autopilot dod gate accepts empty `suites`
only with that exact value.

A run that stops before any suite (zero files changed, a `brg-changed`
error, a detached HEAD, 0 suites selected or a suite not found) writes
no evidence and leaves the last file in place. A reader (a gate,
definition of done, `test-heal`) therefore compares the file's `sha` to
HEAD and its `scope` to the one it needs before trusting it.

## Integration database for a full run

Definition of done item 14 runs `--except unit`, which includes the
integration suite. When the inventory has that suite and the Makefile has
`db` and `migrate` targets, run `make db` then `make migrate` before it,
and note in the report that this run started the database. After the run,
stop only what this run started: `docker compose down` when the
repository has a compose file and nothing in it was up before the run
(never the db-reset target, which drops the data), then show the port is
free. A database that was already up stays up. No `db` target: the suite
runs with the `DATABASE_URL` the environment gives it, and a suite that
cannot connect is "not run (no database)", never a pass.

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

`--cov` and `--cov-report` are added only when `python3 -c "import pytest_cov"`
succeeds; without it pytest stops on "unrecognized
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
- JUnit XML (pytest, gradle, swift test, maestro): `<testsuite tests failures errors skipped time>`
  and `<testcase classname name file line time>`
  with a `<failure message>` or `<error message>` child (both
  count as failed) or `<skipped>`. Gradle: one file per class, sum them.
- xcodebuild stdout: `Test Case '-[Target.Class testName]' passed (N seconds)`
  and `failed`; the failing assertion is the preceding
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
