---
name: health-checks
description: 'Builds /healthz and /readyz endpoints with per-dependency checks, a scheduled synthetic journey suite, uptime probes and alerts. Use when asked to "add health checks", "readiness endpoint" or "uptime monitoring".'
argument-hint: "[service name] [--probe-only]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(ls:*), Bash(make -n:*), Bash(git diff:*), Bash(python3 -c:*), Bash(promtool check:*), Bash(bash *bin/brg-runbook-check*)
---

# health-checks

`/healthz` answers "is the process up". `/readyz` answers "can it do
its job right now", one line per dependency. The synthetic suite
answers "can a user do theirs". Each answer has a place to be read.

Not this: `observability` owns traces, metrics, SLOs and dashboards;
`logging` owns log statements and HTTP request logging; this skill
owns liveness and readiness endpoints, synthetic checks and their alert
rules. Shared names live in
${CLAUDE_PLUGIN_ROOT}/skills/observability/references/telemetry-
conventions.md.

## Inputs

- services and stacks: `cmd/*`, `apps/*`, `services/*`; if none, the
  repository root as one service when a stack file is found (`go.mod`,
  `pyproject.toml`, `package.json`, `build.gradle.kts`, `Package.swift`);
  ambiguous or none: ask one question naming the entrypoint; still
  none: stop, "no service entrypoint found; name the file that starts
  the process".
- dependencies per service: the wiring module and `.env.example`; if
  neither names any, the imports and connection strings in the code;
  still none for a service that clearly has some: ask one question.
- templates: this skill's own `templates/` (`readyz/go.md`,
  `readyz/python.md`, `synthetic-journey.md`, `blackbox.yml`); nothing
  is read from the repository.
- names: check names, alert names, `probe_success` and the readiness
  metrics come from the shared telemetry conventions under
  `observability`'s references; never invent a second name.
- critical journeys: `docs/product/backlog.md` user flows; if absent,
  the routes and screens in the code, top three by centrality.
- Makefile and CI: targets and the `synthetic` job are added when
  `Makefile` and `.gitlab-ci.yml` exist; if absent, the target and the
  job are written to `.scratch/health-monitoring.md` and the report says
  `ci-pipeline` creates the pipeline.
- runbooks: `docs/runbooks/<Alert>.md`; a missing one gets a minimal
  stub and the `runbook` command for the full version.
- uptime monitor decision: an accepted ADR; else the Decisions first
  protocol below; if deferred, the blackbox exporter and say so.

## Steps

**Decisions first.** Before building, run `tech-decision` for the keys
observability (the uptime monitor). `tech-decision` asks only about the keys this task needs that no
accepted ADR, the request or the code already settles, one question at
a time, and records only what the user decides; a key still
awaiting an answer follows
${CLAUDE_PLUGIN_ROOT}/skills/tech-decision/references/decision-protocol.md.

1. Detect the services and their dependencies as in Inputs: database,
   cache, queue, downstream APIs, object storage, secret manager.
2. `/healthz`: returns 200 with `{"status":"ok","version":"<sha>"}`
   and touches nothing. Wired before auth and logged at debug sampled.
3. `/readyz`: copy the checker from `templates/readyz/go.md` or
   `templates/readyz/python.md` (other service stacks: the same shape
   in that language). Every dependency gets a named check with its own
   timeout (default 2 s, total under 5 s), run concurrently. Body:
   `{"status":"ok|degraded|fail","checks":{"<name>":{"status":"ok|fail",
   "duration_ms":N,"error":"<short>"}}}`. Status 200 when every required
   check passes, 503 otherwise; an optional dependency (cache) makes the
   body say `degraded` and still returns 200. Downstream APIs are checked
   against their own `/healthz`, never a business endpoint. Kubernetes
   probes in `k8s/base/` point at these paths with `periodSeconds` and
   `failureThreshold` set so one slow check does not restart the pod
   (`infra` owns the manifests; print the values to set).
4. Synthetic suite: `tests/synthetic/` with one file per critical user
   journey from `templates/synthetic-journey.md`, in the repo's test
   stack (Go test with `//go:build synthetic`, pytest marker
   `synthetic`, Playwright project `synthetic` for web). Reads
   `SYNTHETIC_BASE_URL` and `SYNTHETIC_ENV`. Prod journeys are GET-only
   and use a dedicated read-only probe account; qa journeys may write to
   a probe tenant and clean up. Makefile target `synthetic`.
5. CI: a `synthetic` job in stage `verify` that runs only when
   `$CI_PIPELINE_SOURCE == "schedule"`, matrix over `qa` and `prod`,
   `allow_failure: false`, artifacts the report. Print the schedule to
   create in GitLab (every 15 minutes) and the CI variables it needs.
   Never create the schedule; the engineer does.
6. Uptime: copy `templates/blackbox.yml` to `monitoring/blackbox.yml`
   with one target per public `/healthz` and `/readyz`. Blackbox exporter
   is the default because the infra repo already runs Prometheus. Use an
   external monitor (Better Stack, UptimeRobot) only when nothing outside
   the cluster can probe it, and say so in `status.md`.
7. Alerts: `ReadinessFailing` (`probe_success == 0` for 3 m) and
   `HealthFlapping` (`changes(probe_success[15m]) > 3`) per service in
   `monitoring/alerts/<service>-health.yaml`, each with `runbook_url`.
   Write the stub and print `runbook <Name>` for any runbook missing.
   Then the runbook gate, counted from the rule files:
   `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-runbook-check" monitoring/alerts`
   (zero alerts or any missing runbook exits 1); fix and rerun until it
   exits 0. `promtool check rules` when installed.
8. Status page source: write `docs/operations/status.md`: a table of
   components (one per service and per shared dependency), the health
   source for each (`/readyz` check name, blackbox target, synthetic
   journey), the owner rotation, and who updates the public status page
   during an incident (`incident`).
9. Mobile (react-native, android, ios): a startup check in the
   composition root that calls `/healthz` with a 3 s timeout, reads
   `min_app_version` from the response or a `/version` endpoint, and
   routes to an offline screen or a forced update screen. Result is a
   breadcrumb in the crash reporter, never a blocking dialog on success.
10. Run `make -n synthetic` (or print the native command) and the
    contract.

## Output contract

```
## Health monitoring: <repo>
| Service | /healthz | /readyz | Dependencies checked | Timeout total |
| ... | yes | yes | db, cache, queue, <api> (N) | 5 s |
Services: N; dependencies checked: N (per service above)
Synthetic journeys: N in tests/synthetic/ (qa: N, prod read-only: N)
CI: verify/synthetic on schedule (create: every 15 min, vars: ...) | written to .scratch/
Uptime: blackbox exporter, N targets in monitoring/blackbox.yml
Alerts: <brg-runbook-check counts line, verbatim> (K stubs). Missing: runbook <Name> ...
Status source: docs/operations/status.md (N components)
Mobile startup check: <file> | n/a
```

## Gotchas

- A readiness check that runs a real query on a hot table becomes the
  slow query. `SELECT 1` on a pooled connection, `PING` on the cache,
  a metadata call on the queue.
- Readiness must never depend on a downstream's readiness, only its
  liveness; otherwise one slow service marks the whole chain unready.
- Synthetic journeys against prod are read-only and tagged with a
  `User-Agent: <org>-synthetic/<version>` so they can be excluded from analytics
  and rate limits.
- A flapping probe is usually a timeout set equal to the check's normal
  duration. Widen the probe or fix the check; never raise
  `failureThreshold` to hide it.
- The synthetic account's credentials come from CI variables, masked
  and protected. They never appear in the repo or the report.
- A forced update screen needs a store link that opens; test it on a
  device before the version gate goes live.
