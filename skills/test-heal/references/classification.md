# Classification: what a failing test is evidence of

The loop runs per failing test, one at a time. It picks exactly one class
from the evidence before anything changes, and it never marks a real
regression as healed.

## The evidence to read

- The runner's message and the assertion's expected and received values.
- The trace or attachment: Playwright `trace.zip` and screenshots, Maestro
  screenshots and the view hierarchy, the Compose semantics dump, the
  XCUITest attachment, pytest's captured output, Go's `-v` output.
- The rendered tree at the failing step: what controls exist, with their
  role, accessible name, label and test id.
- The app diff since the last green run, limited to the files the test
  touches.
- The retry result: the same test run again on the same commit.
- The test-case row's expected result, when the test carries a TC id.
- The server's side, whenever the test reached a real server (an
  integration test against a running API, e2e against qa, a contract or
  load run). Start from the request id or trace id in the failure message
  or the Playwright trace's response headers (`x-request-id`,
  `traceparent`), then read, first that exists: the service logs the CI
  job keeps as an artifact, when it keeps them; the log lines with
  that `request_id` or `trace_id` in Loki (`curl -fsS
  http://localhost:3100/loki/api/v1/query_range` on the local stack from
  `observability`, or the engineer's export from Grafana or
  Datadog); the trace in Tempo or the APM; the Sentry event in the test's
  time window. No id and no logs: say "server side not read" in the
  evidence line.
- For a visual test: the expected, actual and diff images Playwright
  writes beside the failure.

## The classes

| Class | Evidence that proves it | Allowed action |
| --- | --- | --- |
| Locator drift | The element is not found, and the rendered tree shows the same control with a different role, name, test id or position; the app diff touches that component's markup only; the row's expected result still appears | Propose the most stable locator |
| Timing | The test passes on retry, or with a condition wait in place of a sleep; the assertion raced a network call, an animation or a background job; the message is a timeout, not a wrong value | Replace the wait with a condition |
| Test data | A 4xx from a fixture, a unique constraint, an expired date, a seed that assumed an empty table; the same test passes with a fresh builder value | Fix the builder or the fixture |
| Environment | Connection refused, a missing binary, an unset variable, a port in use, a database without migrations; the test passes once the service is up, without any edit | Document the fix; run the Makefile target that provides it |
| Visual change | `toHaveScreenshot` failed and the diff image shows a change the app diff made on purpose: a story or task in the commit names the new look, and every oracle in the row other than the baseline still holds | Run `make test-visual-update` and put the new baseline, with the story id, in a commit of its own for a person to look at; never with a code change |
| Real regression | The control is gone, the expected value no longer appears, or the behaviour in the row's expected result is not what the product does; the app diff changed the behaviour, not the markup | None. Report |

Two classes at once means read again. Still unclear: real regression
until proven otherwise. A test that fails with a wrong value (received
200, expected 423) is never timing, whatever the retry does.

## Never heal a regression

A regression is the test doing its job. The test is not edited, its
assertion is not loosened, its wait is not lengthened, and it is not
quarantined. It is reported with the TC id, the story id, the row's
expected result, what the product did instead and the file:line, and the
report suggests the task to open. The agent does not open it.

Signs that a "heal" is hiding a regression: the assertion's expected
value changed; `toBeVisible` became `toBeAttached` or `toHaveCount(1)`
became `toHaveCount(0)`; an exact match became a substring; a status code
range widened; the test now asserts what the code does instead of what
the row says; a baseline png updated in a commit that names no story or
task. Any of these reverts the change and reclassifies.

## What the server side says

The server's logs and trace for the failing request separate three
classes the test's own output cannot:

- An exception, a 5xx or a wrong value logged for that request id, from
  code the app diff changed: real regression, whatever the test says.
- No log line for that request id at all: the request never reached the
  server. Environment (wrong `BASE_URL`, the service down, a proxy) or a
  test that failed before it sent anything.
- A 4xx from validation or a unique constraint on the fixture's own
  request: test data.

A visual diff with no story or task behind it, or one that also breaks a
`ui:` or `not:` oracle, is a real regression, not a visual change.

## Locator rules

1. Find the control by its purpose in the rendered tree: what the user
   would call it, not what its old selector said.
2. Choose in this order, first that works wins:
   - role and accessible name (`getByRole("button", { name: "Retry" })`,
     `onNodeWithContentDescription`, `app.buttons["Retry"]`, Maestro
     `text` or `id`);
   - label (`getByLabel`), placeholder, or a `data-testid` already on the
     element;
   - never a CSS path, an XPath, `nth-child`, an index or a coordinate.
3. No stable handle means the fix is in the app: add the accessible name
   or a test id and say so. That is an app change with the TC id in the
   commit, not a test-only patch.
4. The locator lives in the page or screen object, in one place. When
   several tests fail on one helper, the helper is healed once.
5. A locator that matches two elements is not a heal. Strict mode stays on.

## Timing rules

Replace the sleep or the raced assertion with a condition the framework
waits on: `expect(locator).toBeVisible()`, `extendedWaitUntil`,
`waitUntilExactlyOneExists`, `XCTestExpectation`, pytest with a polling
helper, Go with `require.Eventually`. Never raise a global timeout or
`retries` to make one test pass; a retry that hides drift is the reason
the test is here.

## Data rules

Make the data unique per run (a run id in the email, a clock injected for
dates) or make the fixture create what it assumes. Never fix by ordering
tests, by sharing state between tests, or by truncating a table the test
does not own.

## Environment rules

The test is right and the machine is wrong. Start what a Makefile target
provides (`make db`, `make migrate`, `make dev`); otherwise record the
service, port or variable and the command that fixes it. A test that
only passes after a hand-started service is a Makefile finding: the
target should provide or check it.

## Confirm, then prove nothing else broke

Re-run the healed test twice on the same commit; two passes confirm. Then
run the whole suite it belongs to once. A new failure means the heal
broke something: revert it and report. One pass and one failure is flaky;
after one more attempt with the next plausible class, quarantine it with
a tag, a task id and a deadline. Never delete a quarantined test.
