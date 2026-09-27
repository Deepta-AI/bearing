# Synthetic journey template

<!-- Template guidance: every section below carries a comment saying what goes
     there (What), what a strong entry has (Good) and a one-line example
     (Example). Delete each comment when you fill its section. The skill
     copies this into tests/synthetic/, one file per journey, in the
     repository's own test stack; the code blocks are the shape to copy, not
     text to edit here. Whoever is on call reads a failing journey. -->

One file per critical user journey under `tests/synthetic/`. A journey
is three to seven steps a real user takes, in order, against a deployed
environment. It is not a unit test and not a load test.

## Rules

<!-- What: the rules every journey file obeys, whatever the stack.
     Good: each rule is one a reviewer can check in the file (an env var
     read, a header sent, a method used); prod stays GET-only on a
     read-only probe account and credentials only ever come from masked
     CI variables. Keep these rules as they are unless the skill changes.
     Example: "- A journey that must write is qa only and deletes its probe
     invoice in finally." -->

- Reads `SYNTHETIC_BASE_URL` and `SYNTHETIC_ENV` (`qa` or `prod`); fails
  fast with a clear message when either is unset.
- Sends `User-Agent: <org>-synthetic/<version>` and `X-Request-Id:
  synthetic-<journey>-<uuid>` so the requests can be found in logs and
  excluded from analytics.
- `prod`: GET only, a dedicated read-only probe account, no side effects.
  A journey that must write is `qa` only and cleans up in `finally`.
- Each step asserts status and one field of the body, and records its
  duration. A step over its budget fails the journey even when the
  status is right.
- Credentials from `SYNTHETIC_USER` and `SYNTHETIC_PASSWORD` CI
  variables, masked and protected. Never in the repo.
- Journeys run in under 60 seconds total and are independent of each
  other.

## Journey list (fill in)

<!-- What: the critical user journeys, one row each, from the
     user flows in docs/product/backlog.md or, without one, the top three
     routes or screens by centrality.
     Good: env says qa, prod or both (prod only for read-only journeys);
     the budget is the sum of the step budgets; the reason names the user
     or the money, not "important". Replace the sample rows below.
     Example: "| download_statement | qa, prod | 3 | 5 s | customers pull it
     before every tax filing |" -->

| Journey | Env | Steps | Budget | Why it is critical |
| --- | --- | --- | --- | --- |
| login_and_dashboard | qa, prod | 3 | 4 s | first thing every user does |
| create_invoice | qa | 5 | 8 s | the money path |
| search_customers | qa, prod | 2 | 3 s | most used read |

## Go (`tests/synthetic/login_test.go`)

<!-- What: the Go shape: a test file behind the synthetic build tag.
     Good: every step has a name, a budget and at least a status and one
     body field asserted; the client sets the base URL, User-Agent and
     request id once.
     Example: `step(t, "search", 1000*time.Millisecond, func() { ... })` -->

```go
//go:build synthetic

package synthetic

func TestLoginAndDashboard(t *testing.T) {
    env := mustEnv(t)
    c := newClient(t, env)                                   // base URL, UA, request id
    step(t, "login", 1500*time.Millisecond, func() {
        res := c.post("/auth/login", loginBody(env))         // qa: probe user; prod: read-only probe user
        require.Equal(t, 200, res.Status)
        require.NotEmpty(t, res.JSON["token"])
        c.token = res.JSON["token"].(string)
    })
    step(t, "dashboard", 1500*time.Millisecond, func() {
        res := c.get("/me/dashboard")
        require.Equal(t, 200, res.Status)
        require.Contains(t, res.JSON, "widgets")
    })
    step(t, "logout", 1000*time.Millisecond, func() {
        require.Equal(t, 204, c.post("/auth/logout", nil).Status)
    })
}
```

## Python (`tests/synthetic/test_login.py`)

<!-- What: the pytest shape: a module marked synthetic, one step block per
     user action.
     Good: each step block carries budget_ms and asserts status and one
     field; fixtures read SYNTHETIC_BASE_URL and SYNTHETIC_ENV and fail fast
     when unset.
     Example: `with client.step("search", budget_ms=1000):` -->

```python
import pytest
pytestmark = pytest.mark.synthetic

def test_login_and_dashboard(client, env):
    with client.step("login", budget_ms=1500):
        r = client.post("/auth/login", json=env.login_body)
        assert r.status_code == 200 and r.json()["token"]
        client.token = r.json()["token"]
    with client.step("dashboard", budget_ms=1500):
        r = client.get("/me/dashboard")
        assert r.status_code == 200 and "widgets" in r.json()
    with client.step("logout", budget_ms=1000):
        assert client.post("/auth/logout").status_code == 204
```

## Web (`tests/synthetic/login.spec.ts`, Playwright project `synthetic`)

<!-- What: the Playwright shape for a web journey, run as the synthetic
     project.
     Good: the steps a real user takes, in order, from the base URL; the
     final expectation carries the journey budget as its timeout;
     credentials from the environment only.
     Example: `await expect(page.getByRole("table", { name: "Invoices" }))
     .toBeVisible({ timeout: 3000 });` -->

```ts
test("login and dashboard", async ({ page }) => {
  await page.goto(process.env.SYNTHETIC_BASE_URL!);
  await page.getByLabel("Email").fill(process.env.SYNTHETIC_USER!);
  await page.getByLabel("Password").fill(process.env.SYNTHETIC_PASSWORD!);
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page.getByRole("heading", { name: "Dashboard" })).toBeVisible({ timeout: 4000 });
});
```

## CI job (a stage that exists in `stages`)

<!-- What: the scheduled CI job that runs the suite against qa and prod.
     Good: runs only on schedule, its stage is listed in `stages`, matrix
     over the environments where the journey is safe, JUnit report kept
     always; existing jobs that match schedule pipelines get a rule that
     excludes them; a prod failure reaches the pager; the skill prints the
     schedule and variables for the engineer to create, never creates them.
     Example: "Schedule: every 15 minutes on develop, variables
     SYNTHETIC_BASE_URL_QA and SYNTHETIC_BASE_URL_PROD masked." -->

```yaml
stages: [lint, test, build, deploy, synthetic]   # add the stage if absent

.not-scheduled: &not-scheduled                     # merge into every existing job's rules
  - if: $CI_PIPELINE_SOURCE == "schedule"
    when: never

synthetic:
  stage: synthetic
  allow_failure: false
  rules:
    - if: $CI_PIPELINE_SOURCE == "schedule"
  parallel:
    matrix:
      - SYNTHETIC_ENV: [qa, prod]
  script:
    - make synthetic
  after_script:                                    # failure must page: push a metric an alert watches
    - ./scripts/push-synthetic-result.sh "$SYNTHETIC_ENV" "$CI_JOB_STATUS"
  artifacts:
    when: always
    reports:
      junit: .reports/synthetic-*.xml
```

Alert on `synthetic_last_run_timestamp_seconds` older than two
intervals (catches a stopped schedule) and page only when two
consecutive prod runs failed (a `synthetic_consecutive_failures >= 2`
gauge the push script keeps, or a retry inside the run): the metric
changes once per run, so a `for: 5m` on a 15-minute job pages on one
flaky run. qa failures get the non-paging severity. A failed scheduled
pipeline alone notifies nobody.

Create the schedule in GitLab (every 15 minutes, target the default branch) with
`SYNTHETIC_BASE_URL_QA`, `SYNTHETIC_BASE_URL_PROD`, `SYNTHETIC_USER`,
`SYNTHETIC_PASSWORD` as masked variables. The `make synthetic` target
picks the URL by `SYNTHETIC_ENV`.
