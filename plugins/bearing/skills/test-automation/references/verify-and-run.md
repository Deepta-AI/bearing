# test-automation: verify and run

Read when gating, proving and running the new tests (steps 4 to 7): invented-API gate, visual baselines, mutations, the run and its statuses.

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
6. Prove the tests can fail. A test never seen red may assert nothing.
For each rule the new tests claim to cover, make the smallest
mutation that breaks it, run the suite, then restore the line
(`git diff` shows it clean): a threshold moved one step each way
(`< 5` to `< 4` and to `< 6`, `>` to `>=`), an auth comparison made
always true, a `commit()` or `save` removed, a validation branch
deleted, a publish call dropped, a unit conversion undone. A mutation
no test kills is a missing assertion: add it (a test at the boundary
and one step on each side, a read back through a fresh connection or
a new app instance, a spy on the effect), then re-run the mutation.
Report "mutations: N tried, K killed" and each survivor with why.
Mutations are made in the working tree and always reverted; never
leave one behind, and never run them against a shared environment.
7. Run the narrowest selection that covers the new tests. Flip each passing
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
