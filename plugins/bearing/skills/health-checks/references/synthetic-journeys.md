# health-checks: the synthetic journey

Read when: step 8: only when a scheduled journey suite is asked for.

8. **Synthetic journey** (only when asked). One file per journey from
`templates/synthetic-journey.md`, in the repo's test stack, reading
base URL, environment and credentials from environment variables.
- Per environment, check what each step does there: a step that
  charges a card, sends mail or creates real orders is qa or sandbox
  only (`PAYMENTS_MODE=live` in prod env means prod stops before
  payment or uses read-only calls). Say how prod is covered.
- Credentials from masked CI variables. A token or password already
  committed (a default in a smoke script) is never copied; flag it
  for rotation. Removing that default breaks whatever ran on it (a
  deploy job's smoke step): make the script fail with a clear
  message when the variable is unset, and name the variable each
  existing job now needs before its next pipeline.
- Scheduled CI: the job's `stage` must be in `stages` (add it), the
  job runs only on `$CI_PIPELINE_SOURCE == "schedule"`, and every
  existing job that would also run in a schedule pipeline (rules on
  `$CI_COMMIT_BRANCH == "main"` match schedules too) gets a rule that
  excludes schedules; otherwise a 15-minute schedule rebuilds and
  redeploys every 15 minutes. Print the schedule and its variables
  for the engineer to create; never claim it exists.
- A failed scheduled pipeline notifies nobody by default. Make a prod
  failure reach the pager: push a success/failure metric (Pushgateway,
  a textfile) with an alert on failure and on staleness, or route CI
  failure notifications to the on-call channel, and say which.
  Do the arithmetic against the cadence: a result metric changes
  once per run, so a `for: 5m` on a 15-minute job pages on one flaky
  run. Page when two consecutive prod runs fail (or retry the journey
  inside the run before reporting failure), alert when no result has
  arrived for more than two intervals (a stopped schedule, an expired
  runner token), and keep qa failures off the pager.
