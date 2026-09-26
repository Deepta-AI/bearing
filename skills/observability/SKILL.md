---
name: observability
description: 'Wires OpenTelemetry traces and metrics, trace ids in logs, a local Grafana stack, RED dashboards, SLOs and burn-rate alerts. Use when asked to "add observability", "set up tracing", "add dashboards" or "define SLOs".'
argument-hint: "[service name] [--local-only]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(ls:*), Bash(make -n:*), Bash(docker compose config:*), Bash(python3 -c:*), Bash(promtool check:*), Bash(docker compose -f * config), Bash(make observability-up), Bash(make observability-down), Bash(make dev), Bash(curl -s:*), Bash(npm view:*), Bash(pip index versions:*), Bash(go list -m:*), Bash(bash *bin/brg-runbook-check*)
---

# observability

Three signals, one id. A trace id on the log line, a span around every
call that leaves the process, and RED metrics per route. The dashboard
and the alerts read the same metric names in every service.

Not this: `logging` owns log statements and HTTP request logging
behind the toggle; `health-checks` owns liveness and readiness
endpoints, synthetic checks and their alert rules; this skill owns
traces, metrics, SLOs, dashboards and burn-rate alerts. The shared names
are in `references/telemetry-conventions.md`.

## Inputs

- services and stacks: `cmd/*`, `apps/*`, `services/*`; if none, the
  repository root as one service when a stack file is found (`go.mod`,
  `pyproject.toml`, `package.json` with `react` or `expo`,
  `build.gradle.kts`, `Package.swift`); ambiguous or none: ask one
  question naming the entrypoint; still none: stop, "no service
  entrypoint found; name the file that starts the process".
- service name: `$1`; if absent, the module name (`go.mod`,
  `package.json`, `pyproject.toml`); if absent, the directory name.
- templates: this skill's own `templates/` (collector, compose,
  dashboard, alerts, SLOs); nothing is read from the repository.
- names: `references/telemetry-conventions.md` in this skill holds the
  trace id rule, the log fields, the metric and span names and the alert
  naming that `logging` and `health-checks` share; read it
  before wiring and never introduce a second name for the same thing.
- Makefile: targets are added when it exists; if absent, the compose
  commands are printed verbatim and the report says the Makefile comes
  from `new-repo` or `onboard-repo`.
- `.env.example`: created when absent.
- event sheet for business counter names: `docs/analytics/EVENT_SHEET.md`;
  if absent, names come from the code's domain nouns and the report says
  `analytics-events` is the fuller path.
- runbooks: `docs/runbooks/<Alert>.md`; a missing one gets a minimal
  stub (alert, meaning, first three checks) and the `runbook` command
  for the full version.
- observability decision: an accepted ADR; else the Decisions first
  protocol below.

## Steps

**Decisions first.** Before building, run `tech-decision` for the keys
observability. `tech-decision` asks only about the keys this task needs that no
accepted ADR, the request or the code already settles, one question at
a time, and records only what the user decides; a key still
awaiting an answer follows
${CLAUDE_PLUGIN_ROOT}/skills/tech-decision/references/decision-protocol.md.

1. Detect the services as in Inputs; each one is instrumented. Mobile
   and web apps count as services for crash and performance reporting,
   not for the collector. Before any code, per service, write the
   first two sections of `docs/observability/slos.md` from
   `templates/slos.md`: what working means (one or two sentences per
   user journey, what the user sees when it works) and the two to four
   questions on-call will ask, each mapped to the signal and panel
   that answers it. Ask the engineer for the journeys when the code and
   the event sheet do not name them. Every span, counter and alert
   added below answers one of these questions; one that answers none
   is not added, and a question no signal answers is listed as a gap.
2. Wire the SDK per stack, in the wiring module only (`main.go`,
   `app/main.py`, `src/main.tsx`, `App.kt`, `App.swift`):
   - go-api: `go.opentelemetry.io/otel` with OTLP gRPC to the collector,
     `otelhttp` on the server mux and every client, `otelpgx` or the
     `pgx` tracer, a `slog` handler that adds `trace_id` and `span_id`
     from the span context.
   - python-api: `opentelemetry-sdk` plus FastAPI, SQLAlchemy and httpx
     instrumentation; a structlog processor that copies `trace_id` and
     `span_id` from the current span.
   - react-web: `web-vitals` reported through the API as an event plus
     the `traceparent` header on every `api.ts` call. No browser SDK
     unless the lead asks; it costs bundle size.
   - react-native, android, ios: Sentry (`sentry-expo`,
     `sentry-android`, `sentry-cocoa`) for crashes and performance.
     Chosen over Crashlytics because one vendor covers all three
     clients, propagates `sentry-trace` into server spans, and can be
     self-hosted. Use Crashlytics only when the app already ships
     Firebase and the lead prefers one SDK. PII rules: `sendDefaultPii`
     off, `user` carries the id only, `beforeSend` strips emails, phone
     numbers and request bodies, screenshots off.
   Environment: `OTEL_SERVICE_NAME` and `OTEL_EXPORTER_OTLP_ENDPOINT`,
   added to `.env.example`. No `OTEL_TRACES_SAMPLER` in any
   environment: the SDK keeps its default `parentbased_always_on`
   sampler and every span goes to the collector. Sampling is the
   collector's job (see Gotchas), because the collector's
   `spanmetrics` connector derives RED metrics from spans and a head
   sampler in the SDK would make it count a tenth of the traffic, and
   because only the collector can keep a trace for its outcome (every
   error and every slow request) and change the rate without a
   redeploy. Package versions added here are read from the registry
   at the time (`npm view <pkg> version`, `pip index versions <pkg>`,
   `go list -m -versions <module>`), never written from memory.
3. Metrics: the HTTP instrumentation gives
   `http_server_request_duration_seconds` with `http_route` and
   `http_response_status_code`. That histogram is the RED source; do not
   hand-roll a counter per route. Business counters go through the same
   meter with names from the event sheet or, without one, the code.
4. Local stack: copy `templates/docker-compose.observability.yml` and
   `templates/otel-collector.yaml` to `observability/`. Add
   `observability-up` and `observability-down` to the Makefile
   (`docker compose -f observability/docker-compose.observability.yml
   up -d` and `down -v`), or print them when there is no Makefile.
   Grafana at `http://localhost:3000`, anonymous admin, datasources
   provisioned. Verify with `docker compose -f ... config` and `make -n
   observability-up`.
5. Dashboard: copy `templates/dashboard-red.json` to
   `monitoring/dashboards/<service>-red.json`, set the `service`
   variable default. One file per service. `python3 -c "import json;
   json.load(open(...))"` on each.
6. Alerts: copy `templates/alerts.yaml` to
   `monitoring/alerts/<service>.yaml`, substitute `__SERVICE__` and
   `__RUNBOOK_BASE__`. Every rule keeps its `runbook_url`. For each rule
   whose runbook is missing under `docs/runbooks/`, write the stub from
   Inputs and print the `runbook <AlertName>` command. Then the
   runbook gate, which counts the rules from the files:
   `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-runbook-check" monitoring/alerts`
   (every alert has a `runbook_url` that resolves to a file under
   `docs/runbooks/`; zero alerts fails). Fix what it reports and rerun
   until it exits 0; the report is not done before that. `promtool check
   rules` when installed. Fire each new
   alert once before it counts: lower its threshold for one evaluation
   in the local stack or staging, confirm the notification reaches the
   intended channel and its runbook link opens, restore the threshold,
   and record the fire in the "Alert test fires" table of
   `slos.md`. An alert not fired is reported as "not fired", never as
   working.
7. SLOs: complete `docs/observability/slos.md` (started in step 1,
   never rewritten) with the service's targets. Defaults: availability 99.9 percent,
   latency p95 under 300 ms on reads and 800 ms on writes, error budget
   43 minutes per 30 days, burn-rate alerts as in the rules file.
   Numbers are proposals until the lead confirms; mark them so.
8. Verify locally when `--local-only` is not given and Docker is
   present: `make observability-up`, start the service, one request,
   confirm the trace in Tempo and the log line with the same
   `trace_id` in Loki. Say what was and was not verified.
9. Print the contract.

## Output contract

```
## Observability: <repo>
| Service | Stack | Traces | Metrics | Log trace_id | Crash reporting |
| ... | ... | wired | wired | yes | n/a or Sentry |
Services instrumented: N of N   On-call questions: Q (G without a signal)
Dashboards: N (monitoring/dashboards/)
Alert rules: <brg-runbook-check counts line, verbatim> (K stubs); test-fired: F of N | not run: <reason>
Sampling: SDK always_on; collector: all (local) | tail policy in infra
Missing runbooks: runbook <Name> ...
SLOs: docs/observability/slos.md (targets proposed | confirmed)
Local stack: make observability-up (verified | not run: <reason>)
```

## Gotchas

- The collector is the only exporter target. A service that exports
  straight to Tempo or Prometheus breaks the moment the backend moves.
- `trace_id` on the log line is the whole point. If the handler cannot
  read the span from the context, the middleware order is wrong: tracing
  before logging.
- Sampling happens in the collector, never in the SDK. An SDK ratio
  sampler (`traceidratio` 0.1) decides before the request's outcome is
  known, so it drops nine errors in ten, and the collector's
  `spanmetrics` then undercounts every RED panel built from spans. The
  cost of exporting every span to a collector next to the service is
  small; the production collector does tail sampling (errors, slow
  traces, a share of the rest) after spans are counted, and with more
  than one replica it needs the load-balancing exporter keyed on trace
  id so a trace's spans meet in one place. This follows the
  `otel-instrumentation` guidance; addyosmani's
  `observability-and-instrumentation` suggests low-rate head sampling,
  which the spanmetrics dependency here rules out.
- Instrumentation without a question is noise. A span or counter that
  answers none of the on-call questions in `slos.md` is removed in
  review, however cheap it looked.
- A histogram bucket set that stops at 1 s hides every slow request
  behind `+Inf`. Use the semconv defaults to 10 s.
- Never commit a Sentry DSN for prod; it comes from the secret manager.
  The dev DSN goes in `.env.example` as a placeholder.
- Mobile performance tracing samples at 0.2 or less; every screen load
  as a transaction at 1.0 costs quota and battery.
- The local stack is for laptops. Production observability lives in the
  infra repo (`infra`); this skill never touches it.
