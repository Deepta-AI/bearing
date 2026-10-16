# test-automation: suite setup

Read when creating or extending the suite (step 2): per-stack layout, CI, spec validation, dependencies, test data, tags.

2. Suite. Skip what exists; never replace a working suite. Extending a
suite that already runs in CI changes test files and the case table
only: the Makefile, the CI file and the build stay as they are unless
the request asks, and any change there is named in the report with
its reason. A new gate nobody asked for is scope, not quality.
CI "on every MR": read the whole pipeline file before adding a job.
GitLab `workflow: rules` decide whether a pipeline exists at all; a
job in a file whose workflow admits only the default branch or tags
never runs on an MR however its own rules read. Admit
`$CI_PIPELINE_SOURCE == "merge_request_event"` in the workflow (and
keep a deploy job's own branch rule), put the test stage before
build and deploy, and install what the job needs (the dev extra, not
the runtime install the build job does).
- Web: Playwright in `e2e/`, page objects in `e2e/pages/` from
  `templates/page-object.ts`, fixtures in `e2e/fixtures/`, builders from
  `templates/test-data-builder.md`. When no `playwright.config.ts`
  exists, copy the one from the `bearing-apps:react` or `bearing-apps:nextjs`
  templates (`bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-kit-paths" --skill react`
  prints the directory, or names the plugin to install) (baseURL from
  `BASE_URL`, 2 retries in CI, html reporter) with its projects:
  chromium, firefox, webkit, mobile-chrome and mobile-safari, and a
  `visual` project for `e2e/visual/`. Targets: `make test-e2e` runs
  chromium on every change (CI job `e2e`); `make test-e2e-matrix` runs
  every spec on all five projects (CI job `e2e-matrix` after merge to
  develop and main, manual in an MR); `make test-visual` compares
  `e2e/visual/` with the committed baselines (CI job `visual`). A spec
  that cannot run on a phone carries `@desktop` in its title.
- React Native: Maestro flows in `.maestro/`, one screen file per screen
  as in `templates/screen-object.md`. Target `make test-e2e`; job `e2e`
  in stage `test` on a runner with a simulator. Device matrix: the
  oldest supported and the newest OS on each platform (`DEVICES` in the
  Makefile), run by `make test-e2e-matrix` after merge.
- Android: Espresso and Compose test rules under `app/src/androidTest/`.
  Target `make test-ui`; job `ui-test` in stage `test`. Device matrix:
  Gradle managed devices at `minSdk` and the target SDK in one group,
  `./gradlew <group>GroupDebugAndroidTest` behind `make test-ui-matrix`.
- iOS: an XCUITest target in `project.yml`, tests under `UITests/`.
  Target `make test-ui`; job `ui-test` in stage `test`, macOS runner.
  Device matrix: `xcodebuild test` with one `-destination` per
  simulator (the oldest supported iOS on a small phone, the newest on a
  large one) behind `make test-ui-matrix`.
- Python API: pytest under `tests/`, driving the app in process with
  the client its framework already gives (`httpx.AsyncClient` over an
  ASGI app, the framework's test client, or a small WSGI caller from the
  standard library for a bare WSGI app); repository tests under
  `tests/integration/`. Targets `make test` and `make test-integration`;
  jobs `unit` and `integration` in stage `test`.
- Go API: `httptest` per route; repository tests against Postgres with
  `testcontainers-go` only when the service has a Postgres store. An
  in-memory store, SQLite or no database: no container, and the report
  says why there is no integration job. Targets `make test` (and
  `make test-integration` when there is one); jobs to match in stage
  `test`.
API suites validate every response body against `api/openapi.yaml`
when it exists, inside the route test, so a field the spec lacks or a
wrong type fails the test that caused it: Python `openapi-core`
(`validate_response`), Go `kin-openapi` (`openapi3filter.ValidateResponse`),
Node `ajv` over the operation's response schema. One helper per suite
(`assertMatchesSpec(res, "getInvoice")`), called after every request.
No spec: no validator, and the report says "responses not validated
against a spec".
Dependencies: every library named in this step (a test client, a
container module, a validator, a runner plugin) is used only when the
repository already has it. Adding one to `go.mod`, `pyproject.toml` or
`package.json` is a decision for the engineer: ask once with AskUserQuestion, options
"add <library>" and "do without", naming the library and what it would test;
without a yes (no answer), write the suite with the
standard library and what is already there, and list the dependency
under what was not done.
Test data follows `templates/test-data-builder.md`: reference data comes
from migrations and is only read; each test builds its own rows with a
builder, unique by the run id; the demo seed is never loaded in a test
run. Tests that cross a real HTTP boundary get a fixture that deletes
what it created, and the suite a `make test-data-sweep` target that
removes run-id rows older than a day on qa. Every builder gets one test
that its default passes the API's own validator.
A test that calls a real server puts the response's `x-request-id` (or
the trace id from `traceparent`) in its failure message, so the
server's log line and trace can be found for that exact request.
Every suite gets tags by type and priority (`@e2e @P1`, pytest markers,
Go build tags, Maestro tags), parallel workers, an HTML or JUnit report
kept as a CI artifact. A suite this run creates gets a Makefile
target that fails on zero tests collected and on any failure (no
leading `-`, no `|| true`); no Makefile: create one with that target.
