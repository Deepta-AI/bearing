---
name: node
description: 'Node house rules (Node 24, TypeScript, Fastify 5, Zod, Drizzle, pino, vitest, pnpm). Load before writing or changing Node or TypeScript backend code. Use when asked for "a Fastify route", "a Node API".'
allowed-tools: Read, Grep, Glob, Bash(pnpm install:*), Bash(pnpm run:*), Bash(pnpm exec:*), Bash(pnpm audit:*), Bash(make:*), Bash(npm run:*)
---

# node

The Node stack on this standard: Node 24 (Active LTS), TypeScript 5.9 strict in
ESM, Fastify 5 with `fastify-type-provider-zod` so every route schema is a
Zod 4 schema, Drizzle ORM on `pg` with `drizzle-kit` SQL migrations, pino
through Fastify's logger with a request id on every line, `prom-client` on
`/metrics`, an OpenTelemetry bootstrap that stays off without an endpoint,
vitest with `app.inject`, ESLint flat config, Prettier, pnpm, and a
`node:24-alpine` image running as `node`.

## Inputs

- Source files: the repository as it is; no scaffold is needed. A
  different layout is handled under "On a foreign layout".
- Gate: `make check` when a Makefile has that target; else the native
  commands under Commands, one by one. When `node_modules` is missing and
  nothing can be fetched, do not try an install (not `--offline`, not in a
  copy): say the gate was not run and why, and claim nothing it would prove.
- `references/guidelines.md` and `references/review-checklist.md` ship
  with this skill. `bearing:new-repo` and `bearing:ci-pipeline` are suggestions for a
  repository without a Makefile or a pipeline, never prerequisites.

## When this skill is active

- Writing or changing `.ts` files in a server: apply `references/guidelines.md`.
  Read it once per session, then work.
- Reviewing a diff with Node files: apply `references/review-checklist.md`
  and report every finding as severity (Critical, High, Medium, Low), `file:line`, the claim, a concrete failure scenario and the fix, then list what was checked and found clean and what was not reviewed.
  Rank by consequence (money, another tenant's data, lost writes first),
  check each proposed fix against the trap it claims to close (see
  "Traps"), and end with a verdict: ready, or not ready and why.
- Scaffolding (`new-repo node-api <Name>`): `templates/` holds the
  skeleton and configs; `bin/brg-scaffold` in the bearing plugin copies them. Do not hand-copy.
- Generating CI (`bearing:ci-pipeline`): `templates/.gitlab-ci.yml` is the source.

## Layout

```
src/server.ts             wiring only: config, tracing, pool, app, listen, signals
src/app.ts                buildApp: logger, request id, error mapping, metrics, routes
src/config.ts             Zod over process.env; fails fast and names every bad variable
src/logger.ts             pino options (redaction, pretty in dev); Fastify owns the instance
src/errors.ts             AppError family and the one mapping to the JSON envelope
src/metrics.ts            prom-client registry and the request histogram on /metrics
src/telemetry.ts          OpenTelemetry NodeSDK; a no-op without OTEL_EXPORTER_OTLP_ENDPOINT
src/routes/<resource>.ts  one Zod-typed plugin per resource: parse, call a service, reply
src/<domain>/             services: business rules, no SQL, no Fastify types
src/db/schema.ts          Drizzle tables; src/db/client.ts holds the pool and the handle
drizzle/                  generated SQL migrations; only database's header is prepended, drizzle/meta is never edited
tests/integration/        needs DATABASE_URL; unit tests sit beside the code as *.test.ts
Makefile                  the only entry point: help setup dev check fix test doctor
```

## On a foreign layout

Hard rules anywhere: 1 (validation at the boundary, Zod or the library
the repository uses), 2, 4, 5, 6 (parameterised SQL in one layer) and
7. Advisory: the directory layout, Fastify, Drizzle, pnpm and the
Makefile targets: use the framework, query layer, migration tool and
package manager the repository already has (Express with express-validator,
Kysely, Prisma); propose a switch in an ADR, never inside a feature
change. Say which rule was relaxed and why.

## Rules that matter most

1. Zod at every boundary. Every route declares `schema` (body, params,
   querystring, response) through the type provider; `process.env` is read
   once in `src/config.ts`; a hand-written interface that shadows a schema
   is a finding.
2. Handlers parse, call a service, reply. No SQL, no business rules, no
   error body built in a route; services throw `AppError` subclasses and
   `src/errors.ts` maps them once.
3. Every `async` path awaits or returns its promises. A floating promise
   (`void` without a reason, a forgotten `await` on a reply) is a finding;
   the lint rule is on.
4. Repositories own SQL through Drizzle and return typed rows; services
   own transactions (`db.transaction`); no `db.select` in a route; no
   `sql.raw` with interpolated values.
5. Log through `request.log` or `app.log` so the request id travels; never
   log a token, a password, a cookie or a full body; never `console.log`.
6. Migrations are generated by `drizzle-kit` from `src/db/schema.ts`, read
   line by line, and applied by a release step, never by the container on
   boot. `drizzle/meta` is generated output.
7. `make check` = Prettier check, ESLint (type-checked, zero warnings),
   `tsc --noEmit`, vitest with coverage floors, `pnpm audit` at high. CI
   runs the same target.
8. Shutdown is graceful: SIGTERM closes the server, ends the pool, flushes
   traces, within `SHUTDOWN_TIMEOUT_MS`; `process.exit` appears only in
   `src/server.ts`.

## Traps a strong generalist still misses

Check each one on every change and every review; each has shipped.

- **pg returns int8 and numeric as strings.** `count(*)`, `sum()` over an
  integer or bigint column and every `numeric` arrive as `'2000'`;
  `sql<number>` is a type assertion, not a conversion, so
  `'2000' + 1000` is `'20001000'` and the comparison after it is wrong.
  Convert in the query (`.mapWith(Number)`, `::int`) or at the edge;
  above 2^53 keep a string or `bigint` (and `JSON.stringify` throws on a
  `bigint`).
- **Check-then-write races.** Read a total, compare, insert: two requests
  both pass. A transaction alone does not help at Postgres's default READ
  COMMITTED. Lock the parent row (`SELECT ... FOR UPDATE`), re-check in
  one conditional statement or constraint, or run SERIALIZABLE with a
  retry.
- **Money-moving POSTs are idempotent.** An `Idempotency-Key` per account,
  the first response stored and replayed in the same transaction as the
  write; a reused key with a different body is rejected, not replayed.
- **Side effects after a write.** Never fire and forget (an unhandled
  rejection ends the process by default), never call the network inside a
  transaction (locks held across it), and a bare `await` after commit
  turns a downstream failure into a 500 for a write that happened. Write
  an outbox row or a pending state in the same transaction and let a
  worker retry. Every `fetch` gets `AbortSignal.timeout(ms)`: it has no
  overall deadline of its own.
- **Ownership at every hop.** Every lookup by id carries the account
  condition, including child lists (`/parents/:id/children` checks the
  parent is the caller's, live and not soft-deleted, and answers the same
  404 as an unknown id, not an empty 200 list). A
  negative test needs its positive twin: the owner gets 200 for the same
  id, or the 404 may come from an unmatched route.
- **Keyset paging on timestamps.** Order and cursor on `(ts, id)` in the
  same direction; keep the cursor at stored precision (a JS `Date`
  truncates Postgres microseconds, so rows repeat or vanish between
  pages). Text timestamps compare as text: look at the stored values
  before trusting `ORDER BY`, because an imported `2026-06-05 09:30:00`
  sorts before `2026-06-05T08:00:00.000Z`. Normalise in the query or with
  a data migration, and index what the query actually orders by.
- **Query-string coercion.** `z.coerce.boolean()` turns `"false"` into
  `true` and `z.coerce.number()` turns `""` into `0`; use `z.enum`,
  `z.stringbool()` or an explicit transform. Out-of-range input is a 400,
  never a silent clamp, unless the API says otherwise.
- **Migrations that never run.** The Drizzle migrator applies only what
  `drizzle/meta/_journal.json` lists; a hand-written SQL file is skipped
  and the table is missing in production. A migration applied anywhere is
  never edited.
- **Redaction is by path.** pino's `redact: ['req.headers.authorization']`
  covers Fastify's serialized request, not `request.log.info({ headers })`
  logged by hand; log ids, never headers or bodies.
- **Unit tests that reach out.** A fake that stubs the database but lets a
  real `fetch` run touches the network and can fail the suite through an
  unhandled rejection; a hand-rolled fake cannot show a race or a
  string-typed sum, so those need an integration test.
- **Leave the tree clean.** A database file, log or server started to
  check the work is removed, and only the process ids you started are
  stopped.

## Commands

Each target is used when the Makefile has it; the command after the
colon is the native form (`pnpm exec <cmd>`, or the repository's `npm run`
scripts).

```
make setup           # pnpm install (writes pnpm-lock.yaml), git hooks
make dev             # tsx watch src/server.ts with .env
make check           # prettier --check . ; eslint . ; tsc --noEmit ; vitest run --coverage ; pnpm audit
make fix             # prettier --write . ; eslint --fix .
make migrate         # drizzle-kit migrate
make migrate-verify  # up, snapshot, every Down, up again, diff the schema (CI integration job)
make migrate-new name=add_invoices   # drizzle-kit generate --name add_invoices
make test-integration                # vitest against DATABASE_URL (needs make db and make migrate)
make build           # tsc -p tsconfig.build.json into dist/
```

## Gotchas

- Import suffixes follow the repository: compiled by `tsc` under
  `NodeNext`, relative imports carry `.js` even in `.ts` files; run
  directly by Node's type stripping (or `allowImportingTsExtensions`),
  they carry `.ts`. Copy what the neighbouring imports do. ESM has no
  `__dirname`; use `import.meta.dirname`.
- `startTelemetry` must run before `pg`, `pino` and `http` load, so
  `src/server.ts` imports the app dynamically after calling it. An ESM-only
  dependency needs the loader hook (`@opentelemetry/instrumentation/hook.mjs`)
  registered through `--import`; the CommonJS ones (pg, pino) do not.
- `pnpm-lock.yaml` is committed; CI installs with `--frozen-lockfile` and
  fails when the lock is stale. `pnpm audit --prod` reads the lockfile, so
  a missing lock is a failed gate, not a skipped one.
- Fastify validation errors are 400 with `validation_error`; a response
  that fails its own schema is a 500 with the detail in the log, never in
  the body.
- `requestIdHeader` is `x-request-id`: an incoming id is echoed, a missing
  one is minted as a UUID. Tests assert on the header, not on log output.
- vitest runs units from `src/**/*.test.ts` with no database;
  `vitest.integration.config.ts` runs `tests/integration` and needs
  `DATABASE_URL`. A unit test that opens a connection is a finding.
- The Node major is set in four places that move together: `engines` and
  `@types/node` in `package.json`, `NODE_VERSION` in both CI files, and the
  `FROM` lines of the Dockerfile. The lane follows the Active LTS: Node 24
  until Node 26 becomes Active LTS on 28 October 2026.
