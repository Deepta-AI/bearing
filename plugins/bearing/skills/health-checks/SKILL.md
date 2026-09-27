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
   and grep every path they serve across the repo: kubelet probes
   (`livenessProbe`, `readinessProbe`, `startupProbe`) in the base AND
   in every overlay, patch and per-environment values file (a kustomize
   prod patch that sets its own probe path silently undoes a base fix,
   and prod is usually where the incident was), load balancer
   health checks (GKE `BackendConfig.healthCheck.requestPath`, AWS
   target group `health_check`/`alb.ingress.kubernetes.io/healthcheck-path`,
   nginx upstream checks), blackbox targets, smoke scripts, dashboards,
   docs, the auth middleware's allow list. Moving or retiring a path
   means updating every one of these in the same change, or keeping the
   old path as an alias; never leave a consumer pointing at a 404 or at
   a path that now needs a token. Also find what the old check did wrong
   (a `count(*)` on a hot table, raw `err.Error()` in the body) so the
   report can name it as the cause.

2. **Classify each dependency from the code, not its type.** For each
   client the service builds, read the call sites: if the request path
   falls back when it fails (cache miss reads the database, a quote
   falls back to a list price), the check is optional: it reports
   `fail` and the overall body says `degraded`, status 200. If the
   service cannot serve its core requests without it, required: 503. A
   dependency named only in `.env.example` or removed by an accepted ADR
   gets no check, and the report says why. A probe that cannot fail
   (`func Ping() error { return nil }`, a stub client) is a lie in the
   readiness body: flag it and either implement a real probe or remove
   it from the checks.

3. **`/healthz` (liveness).** Returns 200 with status and version and
   touches nothing: no database, cache, network or lock that a stuck
   dependency can hold. Version comes from the build (`-ldflags -X
   main.version`, a package version, an env var the image sets); if the
   build sets none, omit it rather than invent one. A test runs it with
   every dependency check failing and still gets 200.

4. **`/readyz` (readiness).** Copy the checker from the template for the
   stack. Rules the template carries, keep them when adapting:
   - Checks run concurrently, each with its own timeout, and the handler
     returns at a fixed total deadline even when a probe ignores its
     context (collect results from a channel until the deadline; a
     check with no result by then is reported `fail`, `timeout`). A
     `sync.WaitGroup.Wait()` or `asyncio.gather` with no outer deadline
     hangs on such a probe.
   - The body carries a fixed short reason per check (`timeout`,
     `unreachable`, `unhealthy`), never the driver error. Driver errors
     carry the host, user and database name (pgx: ``failed to connect to
     `user=orders database=orders`: 10.0.0.5:5432 (db.internal)``), and a
     regex scrubber misses some format; log the full error server side,
     sampled.
   - Probes are cheap: `SELECT 1`/ping, `PING` on the cache, a
     downstream's own liveness path (`/healthz`), never its `/readyz`
     (that chains its dependencies into yours) and never a business
     endpoint.
   - Probe the dependency, not your pool. `db.PingContext` on the
     request pool (`database/sql` with `SetMaxOpenConns`, pgxpool,
     SQLAlchemy, HikariCP) first waits for a free connection. At peak,
     when every pod's pool is full and the database is fine, that wait
     times out on every pod at once and readiness turns load into a
     full outage. Read the pool size and any capacity or incident note;
     give the probe its own connection (a second pool capped at 1, which
     costs replicas x 1 connections against `max_connections`, say so)
     and test that a saturated request pool leaves readiness ok.
   - Both endpoints are reachable without credentials: add them to the
     auth allow list or mount them outside the auth middleware, and test
     an unauthenticated request gets 200 or 503, not 401.
   - Tests: all ok 200; each optional failure 200 and degraded; each
     required failure 503 naming the check; a blocking probe that
     ignores its context returns within the total and reports timeout;
     unauthenticated access; liveness with everything down.

5. **Probe arithmetic** (print the numbers in the report):
   - readiness `timeoutSeconds` must exceed the endpoint's worst case
     (the total deadline plus margin). Kubernetes defaults
     `timeoutSeconds` to 1, so a 2 s check behind a default probe times
     out and reads as not ready on every slow ping.
   - liveness points at `/healthz` only, with `failureThreshold x
     periodSeconds` long enough to ride out a GC pause or a CPU-throttled
     second (30 s or more); add a `startupProbe` when start-up is slow
     instead of a long `initialDelaySeconds`.
   - the load balancer health check targets a path that exists without
     a token, and its `timeoutSec` fits the endpoint's worst case.
     Point it at `/readyz` only if you accept the next item.
   - **Shared required dependency.** When every replica shares the
     required dependency (one Postgres), its outage makes every pod
     unready at once: the Service has no endpoints and the edge returns
     its own 502/503 instead of the app's error. That is usually still
     right (no restarts, fast recovery), but it is a trade-off the user
     should see: say it in the report, with the alternative (readiness
     on process state only, dependency status reported but not gating).
   - Values someone tuned for a reason (a comment citing an incident,
     `INC-388: quicker restart of a wedged pod`) keep their intent: move
     the path, keep the timings unless the arithmetic above forces a
     change, and name each changed value and its incident in the report.
   - Manifests owned elsewhere (`bearing-backend:infra`, a platform
     repo): print the exact values to set instead of editing.

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
