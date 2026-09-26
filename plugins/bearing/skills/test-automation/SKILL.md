---
name: test-automation
description: 'Sets up or extends the automated test suite (Playwright, Maestro, Espresso, pytest, Go httptest), one test per planned test case by TC id. Use when asked to "automate the test cases", "set up Playwright" or "e2e tests".'
argument-hint: "[suite|generate] [TC id or story id to limit]"
allowed-tools: Read, Write, Edit, Grep, Glob, Agent, Skill, Bash(ls:*), Bash(make:*), Bash(pnpm exec playwright:*), Bash(pnpm install:*), Bash(pnpm exec tsc --noEmit:*), Bash(maestro test:*), Bash(uv run pytest:*), Bash(uv run --offline:*), Bash(python -m pytest:*), Bash(python3 -m pytest:*), Bash(uv run ruff check:*), Bash(go test:*), Bash(go vet:*), Bash(./gradlew connectedDebugAndroidTest:*), Bash(./gradlew compileDebugAndroidTestKotlin:*), Bash(xcodebuild test:*), Bash(xcodebuild build-for-testing:*), Bash(git diff:*), Bash(python3 *skills/test-automation/scripts/ref_check.py*), Bash(bash *bin/brg-kit-paths*)
---

# test-automation

One row in `docs/testing/test-cases.md`, one test that carries its id. The
suite is the stack's own (never a second framework) and each test mirrors
the nearest existing test. This skill creates suites and generates tests;
running the suites is `test-run` and healing failures is
`test-heal`.

Not this: `test-cases` derives the case table; `test-run` runs
the suites; `test-heal` fixes failures; this skill builds the suite
and writes the tests.

## Inputs

- Stack: looks in the Makefile and `stack.json`; if absent, detects from
  `package.json` (react, expo), `go.mod`, `pyproject.toml`,
  `build.gradle.kts`, `Package.swift` or `project.yml`. None of these:
  stop with "provide a repository with a package manifest".
- Case table: looks in `docs/testing/test-cases.md`; if absent, builds a
  minimal one from the gaps: every route, handler, screen or command with
  no test that names it becomes a row (`TC-0001` up, story `n/a`, AC
  `derived`, automation `planned`), written to `docs/testing/test-cases.md`
  with a header line saying it was derived; the fuller table comes from
  `test-cases`. The suite is created either way.
- Existing tests: the stack's test folders (`e2e/`, `.maestro/`, `tests/`,
  `*_test.go`, `androidTest/`, `UITests/`); if none, the first test is
  written from the templates below instead of mirroring one.
- Templates in this skill's folder: `templates/page-object.ts`,
  `templates/screen-object.md`, `templates/test-data-builder.md`,
  `templates/visual.spec.ts`.
- API contract: `api/openapi.yaml` from `openapi-spec`; if absent, route
  tests assert on the fields the row names and the report says "responses
  not validated against a spec".
- CI: `.gitlab-ci.yml` for the job; if absent, the Makefile target is
  wired and the job snippet is printed for when a pipeline exists.
- Oracles: the row's Oracles column (`ui:`, `data:`, `not:`, `effect:`,
  `inv:`) from `test-cases`; if the table has none, the expected
  result is the only oracle and the report says "no oracles designed".
- Reference gate: `scripts/ref_check.py` in this skill, Python 3 only.

## Steps

1. Mode from `$1`: `suite` or `generate`; no argument runs suite then
   generate. Detect the stack and obtain the case table as in Inputs.
   In `generate` mode, zero rows with automation `planned` and zero gaps:
   report "0 cases to generate" and finish after the suite step.
2. Suite. Skip what exists; never replace a working suite.
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
   `package.json` is a decision for the engineer: ask once, naming the
   library and what it would test; without a yes, write the suite with the
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
   kept as a CI artifact, and a Makefile target that fails on zero test
   files and prints the count. No Makefile: create one with that target.
3. Generate. For each `planned` row (or the story or TC in `$2`), find the
   nearest existing test by feature folder, then fork `test-writer`
   (Agent tool) with the row, the nearest test's path and the naming
   rule; it writes the test in an isolated worktree and returns the
   failing or passing output. The name carries the id: `test("TC-0012
   rejects an expired token")`, `func TestTC0012_RejectsExpiredToken`,
   `async def test_tc_0012_rejects_expired_token`,
   `fun tc0012RejectsExpiredToken`, `func testTC0012RejectsExpiredToken`,
   and `# TC-0012` on line one of a Maestro flow. Where the name cannot
   hold the hyphenated id (Go, pytest, Kotlin, Swift), the literal
   `TC-0012` also goes in a comment on the line above the test: the
   traceability gate links a test to a row by `TC-nnnn` as written, and
   `TestTC0012_` or `test_tc_0012_` alone is not linked.
   A planned row whose test already exists (a test already carries its
   id) gets no second test: run it; when it passes and asserts the row's
   expected result, flip the row to `automated` and report that the table
   was stale; when it asserts something else, report the difference and
   leave the row. Units: the table and the API may count differently
   (rupees and paise, seconds and milliseconds, percent and basis points).
   Take the table's unit from its header or notes and the API's from the
   field name, type or handler; the test sends and asserts in the API's
   unit, converted, with the row's own value in a comment beside it
   (`25000, // 250.00 rupees`). A test that sends the unconverted number
   tests nothing the row describes. Steps become actions,
   each oracle in the row becomes its own assertion (`ui:` a visible or
   accessible-name assertion, `data:` a read through the API or the store
   after the action, `not:` a negative assertion, `effect:` a spy, a mock
   or an event capture, `inv:` a check after every action in the test, `ui: matches baseline
   <name>.png` a `toHaveScreenshot("<name>.png")` in `e2e/visual/` shaped
   like `templates/visual.spec.ts`: API mocked, clock frozen, anything that
   changes on its own masked),
   and the row's test data is used verbatim through a builder. Locators: role and accessible name first,
   test ids second, never CSS paths. A row whose steps cannot be automated
   stays `manual-only` with the reason in its title; never a fake test.
   Batch rows by feature folder so one fork writes several tests. When the
   fork cannot start (no git repository for its worktree, no Agent tool),
   write the tests in place under the same rules and say so in the
   report.
   Property rows: a `unit` row whose oracle is `inv:`, or whose code is
   an encode and decode pair, a parser, a normalizer, a validator, a
   comparator or money arithmetic, is a property candidate. When the
   `property-based-testing` skill is installed, load it through the
   Skill tool before forking and use it to pick, per candidate, the
   strongest property the code supports from its catalog, the generator
   with constraints in the strategy rather than in `assume()`, the
   `@example` edge cases from the row's test data, and the library the
   repository already uses. Pass those to `test-writer` in the fork
   prompt, since the fork has no Skill tool; the test still carries the
   TC id and the row's oracles. It contributes the property and the
   generator; this skill still owns the row, the name, the gates and the
   status. No property-testing library in the repository: adding one is a dependency
   the engineer approves, asked once with the property it would test;
   without a yes, or when the skill is not installed, the row gets
   example tests from its test data and the report says "property: not
   run (<reason>)". A property that only proves "no crash" is not worth
   the dependency; write the example tests.
4. Invented-API gate, before anything runs. A test that calls an id, a
   label, a route or a function the code does not have fails for the
   wrong reason, and a heal later makes it pass against nothing.
   - The stack's type check over the new test files: `pnpm exec tsc
     --noEmit`, `uv run ruff check <files>` (undefined names fail), `go vet
     ./...`, `./gradlew compileDebugAndroidTestKotlin`, `xcodebuild
     build-for-testing`. Every error in a new test is fixed against the
     real code, never by adding what the test expected.
   - `python3 "${CLAUDE_PLUGIN_ROOT}/skills/test-automation/scripts/ref_check.py" --src <source dirs> <new test files>`:
     every test id, accessible name, label, text and route (with its
     method) the new tests use must exist in the source, including routes
     reached through the suite's own request helper. It fails on zero
     references: a batch of pure unit tests has nothing for it to check,
     and the report says "test-refs: 0 references, not a pass; the type
     check was the only gate". A test that calls an unknown route on
     purpose (a 404 or 405 check) carries `ref_check: absent` in a comment
     on that line. A missing reference is fixed against the code or, when
     the code lacks what the criterion needs, reported as a finding with
     the TC id; never by adding the id to the product.
   Print both results.
5. Visual baselines: when step 3 wrote a visual test, run `make
   test-visual-update` (it runs inside the Playwright image, so fonts match
   CI) and list every new or changed png for a person to look at. A
   baseline nobody has looked at proves only that the page renders the
   same as it did, so the report says "baselines to review: N" until the
   engineer commits them, on their own.
6. Run the narrowest selection that covers the new tests. Flip each passing
   row to `automated`. A failing test stays `planned` and is listed with
   the runner's message and its file:line; nothing is edited to make it
   pass. A row the team wrote, in a suite that already runs in CI, fails
   as it is: the row is the spec and the decision is theirs. When this
   run creates the suite's CI job, a job that is red on the day it
   appears blocks every MR for a reason nobody chose: a test that fails
   on a defect this run found carries the stack's strict expected-failure
   marker with the finding as its reason (pytest
   `@pytest.mark.xfail(strict=True, reason="...")`, Playwright
   `test.fail()`), so the job is green now and turns red the day the
   defect is fixed; the row stays `planned` and the finding is reported.
   A route the docs promise and the code does not serve is a finding, not
   a derived row: rows derived from gaps come from what the code serves. A failing property test is listed with its shrunk
   counterexample and the class the property skill's failure reference
   gives it (wrong property, ambiguous spec, code bug). `test-heal`
   classifies and heals it, and `test-run` produces the full report.
7. Print the counts and the file list.

## Output contract

```
## Test automation: <stack> (<mode>)
Suite: created | extended | present (<framework>, <make target>, CI job <name> in stage test)
Case table: docs/testing/test-cases.md | derived from gaps (N routes without tests)
Cases marked for automation: N
Tests generated: G   Tests already existing: E   Left manual-only: S (listed)
Property tests: P (library <name>) | property: not run (<reason>)
Visual tests: V (baselines to review: N, in e2e/__screenshots__/) | none
Browser matrix: <projects> (make test-e2e-matrix) | device matrix: <devices> | n/a
Responses validated against api/openapi.yaml: yes (<helper>) | no spec
Type check: passed | E errors fixed | <tool> absent
test-refs: <ref_check.py counts line, verbatim> | 0 references, not a pass (type check only)
Tests failing after generation: F (left planned; run test-heal)
  TC-nnnn  <file:line>  <runner message>
Files: ...
```

## Gotchas

- A generated test that asserts what the code does instead of the row's
  expected result is a tautology. The row wins. When the code disagrees,
  that is a finding to report, not a test to rewrite. A row derived from a
  gap has only the route's observable contract as its expected result; say
  so in the test's comment.
- The reference gate runs on what the test uses, not on what it
  asserts. A test id that exists but sits on the wrong element still
  passes it; the review and the run catch that.
- Never add a second framework to a stack. Cypress beside Playwright, Detox
  beside Maestro, or unittest beside pytest is a finding.
- Web specs mock the API with `page.route`; a spec that reaches a real
  server flakes. Mobile flows run against a build with a stubbed backend.
- A visual baseline made on a laptop differs from CI in fonts and
  antialiasing, and the first CI run fails for nothing. Baselines are only
  written by `make test-visual-update`, inside the image. Updating a
  baseline to turn CI green is healing a regression unless the change was
  intended; `test-heal` decides which.
- The browser matrix is for behaviour, not layout. A spec that fails only
  on webkit is a finding with the browser in it, never a `test.skip` for
  that browser without a task id.
- Playwright `retries` hides drift. Keep CI retries at 2 and treat a test
  that needed a retry as a candidate for `test-heal`.
- No `.only`, no `skip` without a task id. Quarantine is a tag, a task id
  and a deadline, all three.
- The test name is the traceability link. Renaming it breaks
  `traceability`.
