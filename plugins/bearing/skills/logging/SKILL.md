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
thing.

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
- boundaries: handlers, screens, jobs found under the path; zero found
  still gets the logger module and the request id binding, and the
  report says "0 boundaries; logger established only".
- gate: `make check` when the Makefile has a `check` target; if absent,
  the stack's native command (`go test ./...`, `pnpm test`, `uv run
  pytest`, `./gradlew test`, `swift test`) and the report says the gate
  is improvised.
- `.env.example` and README: created when absent (README gets only the
  logging section).

## Steps

1. Resolve the stack and the path as in Inputs. Read
   `references/logging-guide.md` once, then the stack's section.
2. Inventory the boundaries under the path. Count handlers (Go
   `HandleFunc` and method patterns, FastAPI route decorators), screens
   (RN `app/**` routes, Compose `*Screen` composables, SwiftUI views
   named `*Screen`), jobs and consumers. Print the counts before any
   change.
3. Establish one logger in one module with the stack's library: `slog`
   JSON handler (Go), `structlog` with contextvars (Python),
   `src/lib/log.ts` over `console` with levels (React), `react-native-logs`
   or `src/lib/log.ts` (RN), `Timber` behind the injected `Logger`
   (Android), `os.Logger` with subsystem and category (iOS). Grep for
   `fmt.Println`, `print(`, `console.log`, `Log.d`, `NSLog` outside that
   module and list every hit as a finding.
4. Bind the request id at the edge: middleware for services, the API
   client plus a per-session id for web and mobile. Every line inside the
   request carries it without the caller passing it.
5. Every line names what happened in a stable `event` field
   (`order.created`, `payment.failed`, dotted, past tense, never
   reworded once a dashboard or alert reads it), separate from the
   human `msg`. When the service has several entry points (HTTP, a
   worker, a CLI, a cron), every line also carries `entry_point` so one
   sink can tell them apart. Then add the boundary logs with the field
   names from the guide's table:
   handler entry (`route`, `method`, `user_id` or `tenant_id`) and exit
   (`status`, `duration_ms`, `outcome`); service decisions at info with
   the `entity_id`; repository and external calls at debug with
   `duration_ms` and `target`; queue consume and produce with `queue` and
   `message_id`.
6. Levels: debug for state, info for a business event, warn for a handled
   anomaly, error for a failure with the wrapped error attached. An error
   logged and then rethrown is a finding; log once at the edge.
7. Redaction: tokens, passwords, emails, phone numbers, card numbers and
   full bodies never appear. Use the guide's deny list; log ids instead.
   Then spot-check real output, not only the code: run the service or its
   tests once with `LOG_LEVEL=debug`, capture the lines, and grep them for
   email, phone, card and token shapes. A deny list only covers the
   fields someone thought of; the captured output shows what actually
   leaks. Report the number of lines checked and the hits.
   Sample hot paths (health checks, list endpoints) through the stack's
   sampler with `LOG_SAMPLE`; never sample warn or error.
8. HTTP logging, when `--http` is given or the request asks for it:
   install the stack's middleware or interceptor from
   `templates/http-logging/` (`go.md`, `python.md`, `react.md`,
   `react-native.md`, `android.md`, `ios.md`). Toggles: `LOG_HTTP`
   (default false in production, true in development), `LOG_HTTP_BODIES`
   (default false, `LOG_HTTP_MAX_BYTES` 2048, redacted headers),
   `LOG_HTTP_SAMPLE` (default 1.0). Write into the README how to flip each
   at runtime: env and restart for services, `localStorage` on web, remote
   config or the debug menu on mobile.
9. Update `.env.example` with every toggle read and a comment each. Run
   the gate.
10. Recount handlers or screens with both an entry and an exit log. Print
    the contract.

## Output contract

```
## Logging: <stack> (<N> handlers or screens found)
Logger: <module path> (<library>)
Request id: bound in <file>
| Boundary | Found | Entry and exit after |
| handlers or screens | N | M |
| jobs and consumers | N | M |
Findings: <count> stray print calls, <count> lines with PII or secrets
Events: <count> distinct event names; lines without event: <count>; entry points: <list>
Output spot-check: <N> captured lines, <K> PII or secret hits | not run (<reason>)
HTTP logging: installed in <file> | not requested (LOG_HTTP default <v>)
gate: make check | <native command>: passed | failed (<target>)
```

## Gotchas

- Never log a request body by default. `LOG_HTTP_BODIES=true` is a local
  switch, ships off, and truncates at the max bytes even when on.
- `slog` and `structlog` both let a duplicate key win silently; bind
  `request_id` once at the edge and never add it again in a handler.
- Web and RN bundles ship every log call. The `log` module drops lines
  below the configured level so a production console stays quiet.
- Timber and `os.Logger` redact in release builds (`%{private}` on iOS).
  Mark a field public only if the guide's table lists it as safe.
- Sampling drops lines, not requests. A sampled request still has its
  error line if it fails.
- Field names are the contract with the dashboards. Never rename one for
  a single service; change the table and every service together.
