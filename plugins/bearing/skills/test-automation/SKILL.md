---
name: test-automation
description: 'Sets up or extends automated tests (Playwright, Maestro, pytest), one per TC id. Use when asked to "automate the test cases" or "set up Playwright".'
argument-hint: "[suite|generate] [TC id or story id to limit]"
allowed-tools: Read, Write, Edit, Grep, Glob, Agent, Skill, Bash(ls:*), Bash(make:*), Bash(pnpm exec playwright:*), Bash(pnpm install:*), Bash(pnpm exec tsc --noEmit:*), Bash(maestro test:*), Bash(uv run pytest:*), Bash(uv run --offline:*), Bash(python -m pytest:*), Bash(python3 -m pytest:*), Bash(uv run ruff check:*), Bash(go test:*), Bash(go vet:*), Bash(./gradlew connectedDebugAndroidTest:*), Bash(./gradlew compileDebugAndroidTestKotlin:*), Bash(xcodebuild test:*), Bash(xcodebuild build-for-testing:*), Bash(git diff:*), Bash(python3 *skills/test-automation/scripts/ref_check.py*), Bash(bash *bin/brg-kit-paths*), AskUserQuestion
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
2. Suite. Skip what exists; never replace a working suite; add a dependency only
   after one AskUserQuestion (as `${CLAUDE_PLUGIN_ROOT}/references/console.md` says), options "add <library>" and
   "do without", no answer meaning without. Detail: references/suite-setup.md
3. Generate. For each `planned` row (or the story or TC in `$2`), find the
   nearest existing test, then fork `test-writer` (Agent tool) with the row;
   the test name carries the TC id; a property-testing library is added only on a
   yes to the same kind of question. Detail: references/generating-tests.md
4. Invented-API gate, before anything runs: the stack's type check, then
   `ref_check.py` over the new tests; print both results. Detail:
   references/verify-and-run.md
5. Visual baselines: list every new or changed png for a person to look at.
   Detail: references/verify-and-run.md
6. Prove the tests can fail: make the smallest mutation that breaks each
   rule covered, run, restore; mutations always reverted, never run against a
   shared environment. Detail: references/verify-and-run.md
7. Run the narrowest selection that covers the new tests; flip passing rows
   to `automated`, leave failing ones `planned`; nothing is edited to make a test pass.
   Detail:
   references/verify-and-run.md
8. Print the counts and the file list. Say plainly that the CI pipeline
   was not run (only the local command, named), and list every file
   changed outside the tests and the case table with the reason.

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
Mutations: N tried, K killed (survivors listed with the missing assertion)
Tests failing after generation: F (left planned; run test-heal)
  TC-nnnn  <file:line>  <runner message>
Findings: <defects the tests exposed, each with file and function>
CI: pipeline not run; ran locally with <command>
Changed outside tests: none | <file>: <why>
Files: ...
```

## Gotchas

- A case whose feature was never built (no route, screen or script to
  reach) is a finding, not a test against an invented path: ref_check
  would rightly fail it. Name the case, the missing piece and where the
  design puts it in the report; the case stays `planned` and blocks the
  stage until the feature is built or the case is deferred by a recorded
  decision. A copy label the source builds in a template literal is not
  invented: ref_check matches it.
What a generalist misses when the suite looks green. Detail: references/generalist-misses.md

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
