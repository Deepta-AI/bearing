---
name: health-checks
description: 'Builds /healthz and /readyz endpoints with per-dependency checks, a scheduled synthetic journey suite, uptime probes and alerts. Use when asked to "add health checks", "readiness endpoint" or "uptime monitoring".'
argument-hint: "[service name] [--probe-only]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(ls:*), Bash(make -n:*), Bash(git diff:*), Bash(python3 -c:*), Bash(promtool check:*), Bash(bash *bin/brg-runbook-check*)
---

# health-checks

`/healthz` answers "is the process up". `/readyz` answers "should the
load balancer send this pod traffic right now", one line per
dependency. The synthetic journey answers "can a user do their job".
Probes and alerts turn those answers into a page. Most outages these
mechanisms cause come from wiring, not from the handler: a liveness
probe that touches the database, a probe timeout shorter than the
check, an alert in a file Prometheus never loads, a severity no route
pages on, a schedule that also redeploys. This skill is mostly about
those.

Not this: `observability` owns traces, metrics, SLOs and dashboards;
`logging` owns log statements. Shared metric and check names live in
${CLAUDE_PLUGIN_ROOT}/skills/observability/references/telemetry-
conventions.md.

## Inputs

- the request, which sets the scope (Step 0).
- services: `cmd/*`, `apps/*`, `services/*`, else the repository root
  when a stack file exists (`go.mod`, `pyproject.toml`, `package.json`,
  `build.gradle.kts`, `Package.swift`); none: ask one question naming
  the entrypoint, still none: stop, "no service entrypoint found".
- dependencies: what the code really connects to (the wiring in
  `main`, the clients it constructs), cross-checked against ADRs,
  `docs/`, `.env.example` and the README. The code and an accepted ADR
  win over a stale env file.
- what already exists: the current health handler and every consumer of
  its path (Step 1).
- monitoring config when monitoring is in scope: `prometheus.yml`
  (`rule_files`, scrape jobs), `alertmanager.yml` (routes and matchers),
  the blackbox modules, existing rule files and runbooks.
- CI when a scheduled job is in scope: `.gitlab-ci.yml` (`stages`, every
  job's `rules`), or the repo's other CI file.
- environment files (`deploy/env/*`, Helm values) for what differs
  between qa and prod, above all anything that moves money or emails
  customers.
- templates: `templates/readyz/go.md`, `templates/readyz/python.md`,
  `templates/synthetic-journey.md`, `templates/blackbox.yml`.
- uptime monitor choice: an accepted ADR; else Decisions first below.

## Steps

**Decisions first.** Only when uptime monitoring is in scope and no
accepted ADR names the monitor: run `tech-decision` for the key
observability (the uptime monitor), following
${CLAUDE_PLUGIN_ROOT}/skills/tech-decision/references/decision-protocol.md;
a key still open proceeds on the in-cluster blackbox exporter, marked
Proposed.

0. **Scope.** Build what was asked. "Liveness and readiness endpoints"
   means the endpoints, their wiring, tests, the probe and load balancer
   manifests, and nothing else: no synthetic suite, blackbox config,
   alerts, runbooks or status docs, and no process lifecycle changes
   (SIGTERM drain, `terminationGracePeriodSeconds`, `preStop`), which
   change rollout behaviour. List those as one-line offers in the
   report. "Uptime monitoring and alerting" adds probes, alerts and
   runbooks. "Something that runs the flow every N minutes" adds the
   synthetic journey and whatever makes its failure page someone.
1. **Inventory before changing.** Find the current health handler(s)
   and grep every path they serve across the repo: kubelet probes in the
   base AND in every overlay, load balancer checks, blackbox targets,
   smoke scripts, docs, the auth allow list. Moving or retiring a path
   means updating every consumer in the same change, or keeping the old
   path as an alias; never leave a consumer pointing at a 404 or at a
   path that now needs a token. Detail: references/inventory-and-classification.md
2. **Classify each dependency from the code, not its type.** An optional
   check reports `fail` with the overall body `degraded`, status 200; a
   required one gives 503. A probe that cannot fail is a lie in the
   readiness body: flag it. Detail: references/inventory-and-classification.md
3. **`/healthz` (liveness).** Returns 200 with status and version and
   touches nothing: no database, cache, network or lock that a stuck
   dependency can hold. Detail: references/liveness-and-readiness.md
4. **`/readyz` (readiness).** Copy the checker from the template for the
   stack and keep the rules it carries: concurrent checks under a fixed
   total deadline, a fixed short reason per check and never the driver
   error, reachable without credentials. Detail: references/liveness-and-readiness.md
5. **Probe arithmetic** (print the numbers in the report): readiness
   `timeoutSeconds` must exceed the endpoint's worst case. Manifests owned
   elsewhere (`bearing-backend:infra`, a platform repo): print the exact
   values to set instead of editing. Detail: references/probe-arithmetic.md
6. **Uptime probes** (monitoring in scope). Use the prober the repo
   already runs, through the public hostname a customer uses; label every
   target with its `environment`. Detail: references/uptime-and-alerts.md
7. **Alerts** (monitoring in scope). Read `rule_files` and the
   Alertmanager route tree first, and use exactly the label value that
   reaches the pager. Page on prod only; leave existing rules alone. Then
   the runbook gate, counted from the rule files:
   `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-runbook-check" <rules dir>`
   (zero alerts or a missing runbook exits 1) and `promtool check rules`
   when installed; say "not run" when it is not. Detail: references/uptime-and-alerts.md
8. **Synthetic journey** (only when asked). One file per journey from
   `templates/synthetic-journey.md`, reading base URL, environment and
   credentials from environment variables. A step that charges a card,
   sends mail or creates real orders is qa or sandbox only; a committed
   secret is never copied; print the schedule for the engineer to create,
   never claim it exists. Detail: references/synthetic-journeys.md
9. Mobile (react-native, android, ios), when asked: a startup call to
   `/healthz` with a 3 s timeout routing to an offline or forced-update
   screen; a breadcrumb in the crash reporter, never a dialog on success.

10. Verify: the repo's test target, `make -n` for any target added,
    every YAML written parses. State what was not exercised: manifests
    not applied to a cluster, checks not run against the real
    dependencies (name them), probes and synthetics not run against the
    real environments, tools not installed.

## Output contract

```
## Health checks: <repo>
Scope: <what was asked> | offered, not built: <list>
| Service | /healthz | /readyz | Required | Optional | Removed/none | Total deadline |
Consumers of old path <path>: <file:line -> new target> ...
Probe values: readiness timeout Ns > worst case Ns; liveness N x Ns; LB <path> timeout Ns; overlays fixed: <files>; tuned values changed: <value, incident> | none
Postgres probe connection: <own pool of 1 | shared, why>
Shared-dependency trade-off: <one line>
Uptime: <prober>, N targets (retired targets removed: ...) | n/a
Alerts: <file matching rule_files glob>, prod <paging value> / qa <chat value>, for: Nm over a Ns probe interval; <brg-runbook-check line> | n/a
Synthetic: <journeys>, prod coverage <read-only | none>, stage <name>, pages after <N> failed runs via <...>, stale after <N>m | n/a
Flagged: <always-ok probes, committed secrets, stale config>
Not run: <cluster apply, real dependencies by name, real endpoints, promtool ...>
```

## Gotchas

- Liveness that checks a dependency turns a database failover into a
  restart loop of every pod; readiness is the only place dependencies
  belong.
- Readiness must depend on a downstream's liveness, not its readiness,
  or one slow service marks the whole chain unready.
- A flapping probe is usually a timeout equal to the check's normal
  duration; fix the check or the timeout, never raise
  `failureThreshold` to hide it.
- A readiness endpoint that always answers 200 (status only in the
  body) never removes a pod and never fails a plain 2xx probe. Fix the
  status code and test it.
- Synthetic prod traffic sends `User-Agent: <org>-synthetic/<version>`
  so analytics and rate limits can exclude it.
- A forced update screen needs a store link that opens; test it on a
  device before the version gate goes live.
