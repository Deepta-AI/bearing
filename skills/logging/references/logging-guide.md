# Logging guide

What to log, where, with which names. The field table is shared by every
service on this standard so one Loki or Grafana query works across all of
them; the master copy, with the metric and span names the other telemetry
skills use, is ${CLAUDE_PLUGIN_ROOT}/skills/observability/references/telemetry-conventions.md,
and that file wins when the two differ.

## Principles

- One logger per process, created once, injected or imported. No second
  logger, no `print`, no `console.log` outside the log module.
- JSON in production, human-readable in development. Same fields both.
- Every line inside a request carries `request_id`. When tracing is on,
  it also carries `trace_id` and `span_id` (see `observability`).
- Levels mean one thing each:
  - `debug`: state and timings a developer needs to reproduce a path.
  - `info`: a business event happened (order placed, user invited).
  - `warn`: an anomaly the code handled (retry succeeded, fallback used).
  - `error`: a failure the code could not handle; the wrapped error is a
    field, never interpolated into the message.
- Log once. The edge (handler, consumer, screen) logs the error; the
  layers below wrap and return it.
- Messages are short, lower case, constant strings. Variables go in
  fields, never in the message, so lines group in a dashboard.

## Field names

| Field | Type | Where | Notes |
| --- | --- | --- | --- |
| `ts` | RFC 3339 UTC | every line | set by the handler |
| `level` | string | every line | debug, info, warn, error |
| `msg` | string | every line | constant, lower case |
| `service` | string | every line | repo name |
| `version` | string | every line | git sha or app version |
| `env` | string | every line | dev, qa, prod |
| `request_id` | string | request scope | from `X-Request-Id` or generated |
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
| `target` | string | repo, external | table, service or host name |
| `queue` | string | consume, produce | topic or queue name |
| `message_id` | string | consume, produce | broker id |
| `attempt` | int | retries | 1-based |
| `error` | string | warn, error | wrapped error text |
| `error_kind` | string | warn, error | sentinel or class name |
| `screen` | string | mobile, web | route name |
| `session_id` | string | mobile, web | per app launch |

## What to log at each boundary

| Boundary | Level | Fields |
| --- | --- | --- |
| Handler entry | debug | route, method, user_id, tenant_id |
| Handler exit | info | status, duration_ms, outcome |
| Service decision | info | entity, entity_id, msg says the decision |
| Repository call | debug | target, duration_ms, rows when cheap |
| External call | debug (warn on retry) | target, status, duration_ms, attempt |
| Queue consume | info | queue, message_id, attempt |
| Queue produce | info | queue, message_id |
| Job start and end | info | job name, duration_ms, outcome |
| Screen open | debug | screen, session_id |
| User action | info | screen, action name, entity_id |

## Redaction deny list

Never a value for any of these keys or anything that matches them,
case-insensitive: `authorization`, `cookie`, `set-cookie`, `x-api-key`,
`password`, `passwd`, `secret`, `token`, `access_token`, `refresh_token`,
`otp`, `pin`, `card`, `pan`, `cvv`, `ssn`, `aadhaar`, `email`, `phone`,
`mobile`, `address`, `dob`. Replace with `[redacted]`. Bodies are off by
default; when on, keys in the deny list are redacted before the body is
truncated.

## Sampling

- `LOG_SAMPLE=1.0` logs everything. `0.1` keeps one request in ten at
  debug and info. Warn and error are never sampled.
- Health and readiness endpoints log at debug only, sampled to `0.01`.
- Sampling decisions are made once per request and stored in the context
  so a request is either fully logged or not.

## Per stack

### Go: `slog`

```go
// internal/logging/logging.go
func New(env, service, version string) *slog.Logger {
    var h slog.Handler
    if env == "dev" {
        h = slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelDebug})
    } else {
        h = slog.NewJSONHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelInfo})
    }
    return slog.New(h).With("service", service, "version", version, "env", env)
}

// Request-scoped logger lives in the context; handlers call FromContext.
type ctxKey struct{}
func With(ctx context.Context, l *slog.Logger) context.Context { return context.WithValue(ctx, ctxKey{}, l) }
func FromContext(ctx context.Context) *slog.Logger {
    if l, ok := ctx.Value(ctxKey{}).(*slog.Logger); ok { return l }
    return slog.Default()
}
```

Handler exit: `log.Info("request done", "status", rec.status,
"duration_ms", ms, "outcome", outcome(rec.status))`. Repository:
`log.Debug("query", "target", "invoices", "duration_ms", ms)`. Error:
`log.Error("create invoice failed", "error", err, "error_kind",
errKind(err))`.

### Python: `structlog`

```python
# app/logging.py
def configure(env: str, service: str, version: str) -> None:
    renderer = structlog.dev.ConsoleRenderer() if env == "dev" else structlog.processors.JSONRenderer()
    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.processors.add_log_level,
            structlog.processors.TimeStamper(fmt="iso", utc=True, key="ts"),
            redact_processor,  # deny list above
            renderer,
        ],
        wrapper_class=structlog.make_filtering_bound_logger(logging.DEBUG if env == "dev" else logging.INFO),
    )
    structlog.contextvars.bind_contextvars(service=service, version=version, env=env)
```

Middleware binds `request_id`, `route`, `method`; `clear_contextvars()`
at the start of every request. Route stdlib loggers (uvicorn, sqlalchemy)
through `structlog.stdlib.ProcessorFormatter` so they share the format.

### React: `src/lib/log.ts`

```ts
type Level = "debug" | "info" | "warn" | "error";
const order: Record<Level, number> = { debug: 0, info: 1, warn: 2, error: 3 };
const min: Level = (localStorage.getItem("LOG_LEVEL") as Level) ?? (import.meta.env.DEV ? "debug" : "warn");
const base = { service: import.meta.env.VITE_APP_NAME, version: __APP_VERSION__, session_id: crypto.randomUUID() };
function emit(level: Level, msg: string, fields: Record<string, unknown> = {}) {
  if (order[level] < order[min]) return;
  console[level === "debug" ? "log" : level](JSON.stringify({ ts: new Date().toISOString(), level, msg, ...base, ...redact(fields) }));
}
export const log = { debug: emit.bind(null, "debug"), info: emit.bind(null, "info"), warn: emit.bind(null, "warn"), error: emit.bind(null, "error") };
```

Screens log `screen` on mount at debug; mutations log `info` on success
with `entity_id`; `api.ts` attaches `request_id` from the response header.

### React Native: `react-native-logs` or the same module

Same shape as web. `session_id` is generated at launch and kept in
memory. Transport: console in development, the crash reporter's
breadcrumbs in release (Sentry `addBreadcrumb`), never a file on device.

### Android: Timber behind `Logger`

```kotlin
interface Logger { fun log(level: Level, msg: String, fields: Map<String, Any?> = emptyMap(), error: Throwable? = null) }

class TimberLogger(private val base: Map<String, Any?>) : Logger {
    override fun log(level: Level, msg: String, fields: Map<String, Any?>, error: Throwable?) {
        val line = Json.encodeToString(base + redact(fields) + ("msg" to msg))
        when (level) { Level.DEBUG -> Timber.d(line); Level.INFO -> Timber.i(line); Level.WARN -> Timber.w(error, line); Level.ERROR -> Timber.e(error, line) }
    }
}
```

Plant `Timber.DebugTree()` in debug builds and a tree that forwards warn
and error to the crash reporter in release. Nothing below warn leaves a
release build.

### iOS: `os.Logger`

```swift
let log = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "network")
log.info("request done route=\(route, privacy: .public) status=\(status) duration_ms=\(ms) request_id=\(requestId, privacy: .public)")
```

Interpolated values are private by default; only fields in the table
marked safe (route, status, duration, ids) are `.public`. Read with
`log stream --predicate 'subsystem == "<bundle id>"'` or Console.app.

## Event names and entry points

- `event` is the machine name of what happened: dotted, past tense,
  lower case (`invoice.sent`, `login.failed`). It is a contract with
  dashboards and alerts, so it is never reworded; a new meaning gets a
  new name. `msg` stays free text for people.
- `entry_point` names how the work arrived (`http`, `worker`, `cli`,
  `cron`, `consumer`) when one process has several. One log sink can then
  split them without parsing messages.
- Check the output, not only the code: a captured debug run grepped for
  email, phone, card and token shapes finds what the deny list missed.
