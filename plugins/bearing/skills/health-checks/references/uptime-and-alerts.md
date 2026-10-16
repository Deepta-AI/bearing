# health-checks: uptime probes and alerts

Read when: steps 6 and 7: when monitoring is in scope.

6. **Uptime probes** (monitoring in scope). Use the prober the repo
already runs (the blackbox exporter in `monitoring/`, or the ADR's
choice); add targets for every service in every environment through
the public hostname a customer uses. For `/readyz` use a module that
fails on `"status":"fail"` in the body as well as on non-2xx, so an
app bug that answers 200 while failing still alerts. Remove or flag
targets for services an ADR retired. Label every target with its
`environment` so rules can page on prod only. Read the probe job's
own `scrape_interval` (a job-level override beats `global`): keep it
at 1m or less, since at 5m samples fall out of Prometheus's 5-minute
lookback between scrapes and a `for:` resets on the gap.

7. **Alerts** (monitoring in scope). Before writing a rule, read:
`rule_files` in `prometheus.yml` (name the file to match its glob,
for example `alerts/*.rules.yml`, or extend the list), and the
Alertmanager route tree (which label value reaches the pager
receiver: use exactly that value, for example `severity: critical`;
a value no route matches goes to the default receiver or nowhere).
Rules: probe failing long enough to cover at least two consecutive
probes: `for:` greater than the probe interval (a `for: 3m` on a 5m
probe interval fires on one failed probe), typically 3 to 5 minutes
at a 1m interval; one per service, `runbook_url` in the form the existing
rules use; a runbook stub for each new alert. Page on prod only:
read the on-call policy (docs, the pager receiver's comment) and give
qa and staging a severity that routes to chat, never the paging
value; one rule at the paging severity across all environments wakes
someone for qa. Leave existing rules
alone. Then the runbook gate, counted from the rule files:
`bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-runbook-check" <rules dir>`
(zero alerts or a missing runbook exits 1) and `promtool check rules`
when installed; say "not run" when it is not.
