# Node guidelines

## Project shape

- One entry, `src/server.ts`, that only wires: config, tracing, pool, app,
  listen, signals. Everything testable lives in `src/app.ts` and below.
- `src/routes/<resource>.ts` knows HTTP and Zod. `src/<domain>/` knows
  business rules and domain types. `src/db/` knows Drizzle. Imports point
  downward: routes import domain and db; domain imports db types; db
  imports nothing above it.
- Modules are named for what they provide (`invoice`, `repositories`,
  `health`), never `utils`, `common`, `helpers`, `misc`.
- A module under 400 lines; a function under 30. Split by domain, not by
  layer, once it grows.
- ESM throughout: `"type": "module"`, `module: NodeNext`, relative imports
  with the `.js` suffix when `tsc` compiles (`.ts` when Node runs the
  sources directly; follow the repository), `import.meta.dirname` instead
  of `__dirname`.

## HTTP with Fastify

- `buildApp(deps)` returns the instance; it never listens. Tests call it
  with injected dependencies and use `app.inject`.
- Routes are plugins typed with `FastifyPluginAsyncZod`; every route sets
  `schema` for body, params, querystring and the success response. The
  handler's types come from the schema; nothing is redeclared.
- A route parses, calls one service method, returns a value. Fastify
  serialises it against the response schema; a mismatch is a 500 logged
  server-side, never a lenient body.
- Errors: services throw `AppError` subclasses (`NotFoundError`,
  `ConflictError`, `ServiceUnavailableError`); `registerErrorHandling` maps
  them, Zod validation errors (400), Fastify client errors (their status)
  and everything else (500, detail hidden) to one envelope
  `{ error: { code, message, details, requestId } }`.
- Request id: `x-request-id` is accepted or minted, bound to `request.log`,
  echoed on every response. One request log line in `onResponse` with
  method, route pattern, status and duration.
- `bodyLimit` set; `trustProxy` only behind a known proxy; timeouts on the
  server and on every outbound client.
- `/healthz` (process up), `/readyz` (pool answers `SELECT 1`, or "not
  configured" without a database), `/metrics` (prom-client) on every
  service. Probes are excluded from request logging and tracing.

## Database with Drizzle

- The stack is Drizzle on `pg`: a typed query builder with a schema-as-code
  file that `drizzle-kit` diffs into SQL migrations. Why not Prisma: a
  second schema language and a query engine binary. Why not raw `pg`:
  hand-written row mapping and no migration diff.
- One `pg.Pool` per process, created in `server.ts`, wrapped once with
  `createDb`, decorated on the app as `app.db`, ended in `onClose`.
- Repositories own SQL. One module per aggregate; functions take the `Db`
  (or a transaction handle) and return typed rows or domain values, never
  a raw result. No `db.select` anywhere outside repositories.
- Services own transactions: `db.transaction(async (tx) => ...)` wraps the
  unit of work; repositories accept `tx` and never commit.
- Every list query is bounded: `limit` with a validated maximum and a
  stable `orderBy`. An unbounded select is a finding.
- `sql` template tags are parameterised by construction; `sql.raw` only for
  identifiers that come from code, never from input.
- Migrations: `make migrate-new name=...` generates from
  `src/db/schema.ts`; read every line, add an index decision comment for
  every new filter, keep `drizzle/meta` as generated. Applied by a release
  step (`make migrate` against the target), never on container boot.
  Destructive changes follow expand and contract.

## Async

- Every function on a request path returns a promise that is awaited or
  returned. `@typescript-eslint/no-floating-promises` is on; a `void` needs
  a comment saying why the result does not matter.
- Outbound calls use `fetch` with `AbortSignal.timeout(ms)` or a client
  built once in `server.ts` with a timeout; never a call with no bound.
- Background work has an owner: a queue with a consumer, or a task list
  the shutdown path drains. A fire-and-forget promise whose rejection
  nobody sees is a finding.
- Shutdown: `SIGINT` and `SIGTERM` call `app.close()` (which ends the
  pool through `onClose`), flush the trace SDK, then exit; a timer bounds
  the whole thing with `SHUTDOWN_TIMEOUT_MS`.

## Configuration

- `src/config.ts` parses `process.env` with Zod once: typed fields, enums
  for choices, defaults for what is safe to default, no default for a
  secret. An empty string counts as unset. Construction throws with every
  bad variable named.
- Nothing else reads `process.env`. `.env.example` lists every variable
  with a placeholder.

## Logging and observability

- pino through Fastify: JSON lines in production, `pino-pretty` when
  `LOG_PRETTY=true`. `request.log` inside a request (request id bound),
  `app.log` outside. Redaction covers `authorization`, `cookie` and
  `set-cookie`.
- Never a body, token, password or email in a log line. Log ids.
- `startTelemetry` is a no-op until `OTEL_EXPORTER_OTLP_ENDPOINT` is set;
  then `http`, `pg` and `pino` are instrumented and spans export over
  OTLP/HTTP. It runs before those modules load (dynamic import of the app
  in `server.ts`). Nothing else imports `@opentelemetry/*`.
- `/metrics` exports process defaults plus
  `http_request_duration_seconds` labelled by method, route pattern and
  status. Never label by raw URL.

## Testing

- vitest. Units sit beside the code as `*.test.ts` and build the app with
  `buildApp` per test, injecting a failing readiness check or a fake
  service; they never open a database or a socket.
- `tests/integration` runs with `vitest.integration.config.ts` against the
  migrated database in `DATABASE_URL`, one file at a time, each test
  inside a transaction that rolls back (`tx.rollback()`).
- Deterministic: `vi.useFakeTimers()` for time, no sleeps, no network.
- Coverage floors are 80 percent on lines, branches, functions and
  statements over `src/` (minus `server.ts`). A bug fix ships with its
  test.

## Typing and style

- `strict`, `exactOptionalPropertyTypes`, `noUncheckedIndexedAccess`,
  `verbatimModuleSyntax`. No `any` unless the value is genuinely open
  (`unknown` then narrow). `@ts-expect-error` only with a reason.
- Types are `z.infer<typeof schema>` at boundaries; plain `interface` for
  internal shapes; no class where a function and a type do.
- Prettier and ESLint decide style. Nothing is discussed in review that a
  tool decides. Imports ordered builtin, external, internal, relative.
- Doc comments on every exported identifier, one line, saying what it is
  for. Comments explain why.
