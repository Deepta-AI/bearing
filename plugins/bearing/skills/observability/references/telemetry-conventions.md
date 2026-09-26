# Telemetry conventions

The names that logs, traces, metrics, health endpoints and alerts share,
so one query works across every service. `logging`,
`observability` and `health-checks` all read this file and
none of them restates it. A change here is a change to every dashboard;
make it once, with the services that consume it.

## The one id

- `request_id`: from `X-Request-Id` when the caller sends one, else
  generated at the edge (UUID v7). Bound once by the middleware or the
  API client; every log line inside the request carries it; every
  outbound call forwards the header.
- `trace_id` and `span_id`: from the active OpenTelemetry span, copied
  onto every log line by the log handler (`slog` handler, `structlog`
  processor, the `log` module on web and mobile). Propagation uses the
  W3C `traceparent` header; mobile crash reporters carry `sentry-trace`
  into the server span.
- The request id is for humans and support tickets; the trace id joins
  logs to spans. Both appear on the line when a span is active.

## Log fields

| Field | Type | Where | Notes |
| --- | --- | --- | --- |
| `ts` | RFC 3339 UTC | every line | set by the handler |
| `level` | string | every line | debug, info, warn, error |
| `msg` | string | every line | constant, lower case |
| `service` | string | every line | repository name; equals `service.name` on spans |
| `version` | string | every line | git sha or app version |
| `env` | string | every line | dev, qa, prod |
| `request_id` | string | request scope | see above |
| `trace_id` | hex | request scope | when a span is active |
| `span_id` | hex | request scope | when a span is active |
| `user_id` | string | after auth | id only, never email or name |
| `tenant_id` | string | after auth | when multi-tenant |
| `route` | string | handler | pattern, not the concrete path |
| `method` | string | handler | GET, POST |
| `status` | int | handler exit | HTTP status |
| `duration_ms` | int | every timed call | wall clock, integer |
| `outcome` | string | exit lines | ok, client_error, server_error |
| `entity` | string | service | aggregate name (invoice) |
| `entity_id` | string | service | id of the aggregate touched |
| `target` | string | repository, external | table, service or host name |
| `queue` | string | consume, produce | topic or queue name |
| `message_id` | string | consume, produce | broker id |
| `attempt` | int | retries | 1-based |
| `error` | string | warn, error | wrapped error text |
| `error_kind` | string | warn, error | sentinel or class name |
| `screen` | string | mobile, web | route name |
| `session_id` | string | mobile, web | per app launch |
| `check` | string | readiness | dependency check name |

Levels mean one thing each: `debug` state and timings, `info` a business
event, `warn` an anomaly the code handled, `error` a failure it could not
handle. Log once, at the edge. Never a token, password, email, phone,
card number or full body; the deny list is in
`${CLAUDE_PLUGIN_ROOT}/skills/logging/references/logging-guide.md`.

## Metric names

- HTTP: `http_server_request_duration_seconds` (histogram, semconv
  buckets to 10 s) with `http_route`, `http_request_method`,
  `http_response_status_code`, `service_name`. This histogram is the RED
  source for every dashboard and burn-rate rule; no hand-rolled counter
  per route.
- Clients: `http_client_request_duration_seconds` with `server_address`
  and `http_response_status_code`.
- Database: `db_client_operation_duration_seconds` with `db_system`,
  `db_operation_name`, `db_collection_name`.
- Queues: `messaging_process_duration_seconds` and
  `messaging_client_consumed_messages` with `messaging_destination_name`.
- Business counters: `<domain>_<event>_total`, names taken from the
  event sheet (`docs/analytics/EVENT_SHEET.md`) when one exists.
- Health: `probe_success` and `probe_duration_seconds` from the blackbox
  exporter with `instance` = the probed URL; readiness checks export
  `readyz_check_duration_seconds{check="<name>"}` and
  `readyz_check_up{check="<name>"}`.
- LLM: `llm_calls_total`, `llm_cost_usd_total`, `llm_fallback_total`,
  `llm_request_duration_seconds` with `feature`, `tier`, `model`.
- Labels are low cardinality: a route pattern, never a concrete path; a
  tenant id only when tenants number under a few hundred.

## Span names and attributes

- Server spans: `<METHOD> <route pattern>`; client spans:
  `<METHOD> <host>`; database spans: `<operation> <table>`; queue spans:
  `<destination> <process|publish>`.
- Every span carries `service.name`, `service.version`,
  `deployment.environment.name`; request spans add `enduser.id` (the id
  only) and `tenant.id`.
- GenAI spans use the semconv `gen_ai.*` attributes listed in
  `llm-gateway`.

## Alert and health names

- Alert names are CamelCase, prefixed with the service:
  `<Service>ErrorBudgetBurnFast`, `<Service>ReadinessFailing`,
  `<Service>HealthFlapping`. The runbook file is
  `docs/runbooks/<AlertName>.md`, spelled exactly as the alert fires,
  and the rule carries `runbook_url`.
- Health endpoints are `/healthz` (process up, touches nothing) and
  `/readyz` (one named check per dependency, each with its own timeout);
  the body shape is in `health-checks`.
- Synthetic probes send `User-Agent: <org>-synthetic` so dashboards,
  rate limits and analytics can exclude them.

## Who owns what

- `logging`: the log statements, the logger module, request id
  binding, HTTP request logging behind `LOG_HTTP`.
- `observability`: traces, metrics, SLOs, dashboards, burn-rate
  alerts, the collector and the local stack.
- `health-checks`: `/healthz` and `/readyz`, synthetic journeys,
  uptime probing, readiness and flap alerts, the status source.
