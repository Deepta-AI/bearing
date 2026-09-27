---
name: logging
description: 'Adds structured logging: one logger, request id bound at the edge, shared field names, redaction, sampling, HTTP request logs. Use when asked to "add logging", "improve the logs", "log the requests" or "fix the logs".'
argument-hint: "[path or package] [--http]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(make:*), Bash(go test:*), Bash(pnpm test:*), Bash(uv run pytest:*), Bash(./gradlew test:*), Bash(swift test:*)
---

# logging

A log line that cannot be joined to the request that produced it is a
sentence without a subject. Every line carries the request or trace id,
the field names every other service uses, and a level that means one
thing. Most logging bugs are not missing lines: they are lines that
leak, lines that lie (status 0, a lost panic, a swallowed error) and
changes that quietly break the code they wrap. This skill is mostly
about those.

Not this: `observability` owns traces, metrics, SLOs and dashboards;
`health-checks` owns liveness and readiness endpoints, synthetic
checks and alert rules; this skill owns log statements and HTTP request
logging behind the toggle. Shared names live in
${CLAUDE_PLUGIN_ROOT}/skills/observability/references/telemetry-
conventions.md.

## Inputs

- stack: detected from `go.mod` (go-api), `pyproject.toml` (python-api),
  `package.json` with `react` (react-web) or `expo` (react-native),
  `build.gradle.kts` (android), `Package.swift` or `*.xcodeproj` (ios);
  more than one match or none: ask one question.
- path: `$1`; if absent, the repository root.
- guide and templates: this skill's own `references/logging-guide.md`
  and `templates/http-logging/`; nothing is read from the repository.
- field names and the request id rule: the shared telemetry conventions
  under `observability`'s references; the guide's table is a copy
  of that file and the conventions win when they differ.
- entry points: every `main` or process start (API, worker, CLI, cron)
  and every place work leaves the request (goroutine, thread, task,
  queue message).
- gate: `make check` when the Makefile has a `check` target; if absent,
  the stack's native command (`go test ./...`, `pnpm test`, `uv run
  pytest`, `./gradlew test`, `swift test`) and the report says the gate
  is improvised.
- `.env.example` and README: the existing ones are extended in place;
  created only when absent.

## Steps

1. Resolve the stack and the path. Read `references/logging-guide.md`
   once, then the stack's section. Read every existing log call, every
   error constructor (`fmt.Errorf`, `raise ...(f"...")`, `new Error`)
   and every process entry point before changing anything: the leaks
   and the swallowed failures are found there, not in the handlers.
2. One logger in one module with the stack's library: `slog` JSON
   handler (Go), `structlog` with contextvars (Python), `src/lib/log.ts`
   (React), `react-native-logs` or `src/lib/log.ts` (RN), `Timber`
   behind the injected `Logger` (Android), `os.Logger` (iOS). Route the
   runtime's own output through it too: in Go `slog.SetDefault` sends
   `log.Print*` through the handler and `http.Server{ErrorLog:
   slog.NewLogLogger(h, slog.LevelError)}` catches the server's own
   errors; in Python `ProcessorFormatter` for uvicorn and friends. List
   every `fmt.Print`, `print(`, `console.log`, `Log.d`, `NSLog` outside
   that module and remove each.
3. Request id at the edge, outermost after recovery: validate an
   incoming `X-Request-Id` (length cap, `[A-Za-z0-9._-]`), else generate
   one; put a request-scoped logger in the context; echo the id in the
   response header. It must sit outside auth so a 401 line carries it.
   Bind it once; a handler that adds `request_id` again writes the key
   twice (slog and structlog do not dedupe).
4. Follow the id across every async hop (the step generalists miss):
   - Go goroutine outliving the request: pass
     `context.WithoutCancel(r.Context())`, never `r.Context()` (the
     request's cancellation kills the work as soon as the handler
     returns, and a ctx-aware client fails with `context canceled`) and
     never a bare `context.Background()` (the id is lost). Python:
     `asyncio.create_task` copies contextvars, a thread or executor does
     not; use `contextvars.copy_context().run`.
   - Queue or table handed to a worker: the consumer cannot see the
     producer's context. Log the entity id (`order_id`) under the same
     key in both processes, or carry the request id in the message, so
     one query joins the API and worker lines for one entity.
   - Every process names itself with `entry_point` (`http`, `worker`,
     `cli`, `cron`) on the base logger.
5. Lines and levels. Each line: constant lower-case `msg`, a stable
   dotted past-tense `event` (`order.created`), variables in fields
   from the guide's table. Levels: debug for state, info for a business
   event, warn for a handled anomaly or a client mistake (4xx), error
   only for a failure the service owns (5xx, a failed dependency). Log
   once, at the edge: the service layer returns a wrapped error, the
   handler or consumer logs it. Loop and batch traps:
   - A worker tick that did nothing logs at debug, or not at all; info
     every few seconds is noise that buries the real lines.
   - A batch that returns only its first error hides the rest: log each
     failed item with its id where it fails, then return the summary.
   - A process start that fails (`ListenAndServe`, a bad config) logs
     one error line and exits non-zero; `_ = http.ListenAndServe(...)`
     exits 0 in silence.
   - Recovery middleware logs a panic once at error with the request
     id and the stack, answers 500, and re-panics `http.ErrAbortHandler`
     rather than logging it.
6. Redaction. Tokens, keys (whole or a prefix), passwords, emails,
   phone numbers, card numbers and bodies never appear. Three places
   leak that a deny list misses:
   - error text: `fmt.Errorf("create order for %s: %w", email, ErrX)`
     puts the address in every line that logs the error. Fix the
     constructor: name the entity by id and keep the `%w` chain so
     `errors.Is` still works. Replacing the error with a constant loses
     the cause and is not a fix.
   - structs logged whole (`%+v`, `"req", req`): log chosen fields.
   - URLs: log `r.Pattern` or the path, never `r.URL.String()` or
     `RequestURI` (the query string carries `?email=`, tokens).
   Then check the output, not the code: add a test that captures the
   logger into a buffer, drives the real failure paths with a known
   email and phone (rejected, blocked, dependency failure, worker run),
   and fails if either string appears. Report lines checked and hits.
7. HTTP request logging, when `--http` is given or the request asks for
   it (and the completion line in any case): one middleware from
   `templates/http-logging/` wrapping the whole chain including auth.
   Its traps, each of which a passing unit test will not show:
   - the response wrapper defaults status to 200 (a handler that never
     calls `WriteHeader` is a 200) and keeps `Flush` and `Unwrap` so
     streaming handlers still stream;
   - the line is written in a `defer` (or `finally`) so a panicking
     request still gets its line with status 500;
   - a request the mux never matched (a 401 from auth, a 404) logs the
     path, since there is no pattern;
   - health checks log at debug or are sampled; sampling is decided
     once per request and never drops a 5xx or an error line;
   - bodies off by default; if offered, a separate switch, capped at a
     byte limit, deny-list keys redacted, and the handler still reads
     the full body.
   Toggle: `LOG_HTTP` with one documented default. If the repo already
   names its environment, derive the default from that; otherwise do not
   invent an environment variable, pick a default and state in the
   README what production gets when the variable is unset.
8. Test through the real chain. Build the handler chain in one function
   that `main` and the tests both call, then drive it with
   `httptest.NewServer` (or the stack's client) so the tests see the
   middleware order production runs. Tests that call a handler directly
   hide every wrapper bug above. Cover: 401 line has a request id,
   panic gives one error line and a 500, streaming export still
   streams, no PII in captured output, toggle off logs nothing.
9. Configuration: add every variable the code now reads to the existing
   `.env.example` (one comment each) and as rows of the README's
   existing configuration table, not a second table. Add only the
   variables the request needs; `LOG_LEVEL` is fine, a new environment
   selector or sampler nobody asked for is scope creep. Run the gate.

## Output contract

```
## Logging: <stack>
Logger: <module path> (<library>); stdlib and server errors routed: yes | no
Request id: bound in <file>, outside auth: yes | no; async hops: <list and how each carries it>
Removed: <count> stray print calls, <count> lines or error texts carrying PII or secrets
Output check: <N> captured lines, <K> PII or secret hits | not run (<reason>)
HTTP logging: <file>, LOG_HTTP default <v> | not requested
Config: <variables> added to .env.example and the README table
gate: make check | <native command>: passed | failed (<target>)
```

## Gotchas

- Never log a request body by default. `LOG_HTTP_BODIES=true` is a local
  switch, ships off, and truncates at the max bytes even when on.
- `r.Pattern` is set by the mux on the request it receives. An outer
  middleware sees it only if no middleware in between replaced the
  request with `r.WithContext`; otherwise fall back to the path.
- `slog` and `structlog` both write a duplicate key twice; bind
  `request_id` once at the edge.
- Web and RN bundles ship every log call. The `log` module drops lines
  below the configured level so a production console stays quiet.
- Timber and `os.Logger` redact in release builds (`%{private}` on iOS).
  Mark a field public only if the guide's table lists it as safe.
- Field names are the contract with the dashboards. Never rename one for
  a single service; change the table and every service together.
