---
name: go
description: 'Go house rules (net/http, pgx, sqlc, goose, slog, table-driven and httptest tests). Load before writing or changing any Go code. Use when asked for "a Go handler", "sqlc queries" or a new Go service.'
allowed-tools: Read, Grep, Glob, Edit, Write, Skill, Bash(go build:*), Bash(go test:*), Bash(go vet:*), Bash(gofmt:*), Bash(golangci-lint run:*), Bash(make:*)
---

# go

The Go stack on this standard: Go 1.25 or newer, standard library `net/http` mux, `pgx` for
PostgreSQL, `sqlc` for typed queries, `goose` for migrations, `slog` for
logs, `golangci-lint` for lint, `govulncheck` in CI.

The Go version that matters is the `go` line in the repository's `go.mod`,
not the toolchain on the machine: it decides the language semantics (a
per-iteration loop variable from 1.22, so `tc := tc` is dead code and a
closure over `tc` is not a bug). New scaffolds pin `go 1.26.8`; with an older
local toolchain and `GOTOOLCHAIN=local` they do not build, so say so rather
than lowering the `go` line or letting a toolchain download.

## Inputs

- Go files: the repository as it is; no scaffold is needed. A
  different layout is handled under "On a foreign layout".
- Gate: `make check` when a Makefile has that target; else the native
  commands under Commands, one by one.
- `references/guidelines.md` and `references/review-checklist.md` ship
  with this skill. `bearing:new-repo` and `bearing:ci-pipeline` are suggestions for a
  repository without a Makefile or a pipeline, never prerequisites.

## When this skill is active

- Writing or changing `.go` files: apply `references/guidelines.md`. Read it
  once per session, then work.
- Reviewing a diff with Go files: review the branch against its merge base
  (`git diff main...HEAD`, commit by commit), never edit the tree; probe in
  a copy under a scratch folder. Apply `references/review-checklist.md` and
  report each finding as severity (Critical, High, Medium, Low), `file:line`,
  the claim, the concrete failing request or state, and the fix. Rank by
  consequence (cross-tenant data, injection, a process crash, money first).
  Mark what already exists on main as pre-existing. Drop a nit that has no
  failure to name. Say which checks you ran and which you did not.
- Scaffolding (`new-repo go-api <Name>`): `templates/` holds the skeleton
  and configs; `bin/brg-scaffold` in the bearing plugin copies them. Do not hand-copy. A
  command-line tool (no server, no database) is `new-repo go-cli
  <Name>` from `templates-cli/`: the standard library, one binary, the same
  gates.
- Generating CI (`bearing:ci-pipeline`): `templates/.gitlab-ci.yml` is the source.
- Pack skills (samber/cc-skills-golang), when installed, are deeper than
  this skill on Go itself; load the one the job needs with the Skill
  tool: `golang-concurrency` for goroutines, channels, sync and errgroup;
  `golang-context` for cancellation, deadlines and `WithoutCancel`;
  `golang-error-handling` for error types and the log-or-return rule;
  `golang-testing` for tests (synctest, goleak, fuzzing); `golang-database`
  for pgx repository code; `golang-security` when code touches auth,
  crypto, file paths, outbound URLs or user input; `golang-safety` for
  nil, aliasing and numeric conversions; `golang-observability` for
  metrics and spans, under the names `bearing:observability` sets;
  `golang-performance` only after a profile names the hotspot;
  `golang-code-style` for style review.
- This skill explicitly supersedes the pack on the stack: sqlc, goose and
  pgx (not golang-migrate, sqlx or Atlas); schemas and migrations are
  written, via `bearing:db-migration` and `bearing:database`, and the pack's bans on
  writing schemas and on RLS, triggers and views give way to
  `bearing:database`; tools stay pinned in `tools/go.mod` (never the pack's
  `go install ...@latest` or `go get -tool` into the service module); a
  library the pack suggests (samber/lo, samber/oops, testify, gotests) is
  a dependency added unasked until the user agrees; the layout, the
  Makefile and `make check` are the gate.
- Pack not installed: `references/guidelines.md` and the checklist are
  the whole guidance; nothing else changes.

## Layout

```
cmd/api/main.go           wiring only: config, logger, db, server, signals
internal/config/          env parsing with defaults and validation
internal/httpapi/         handlers, middleware, routes (one file per resource)
internal/<domain>/        services: business rules, no SQL, no HTTP types
internal/store/           sqlc output plus hand-written repositories
db/migrations/            goose migrations, NNNN_name.sql with Up and Down
db/queries/               sqlc query files
tools/go.mod              developer tools pinned with the tool directive
Makefile                  the only entry point: help setup dev check fix test doctor
```

## On a foreign layout

Hard rules anywhere: 1, 2, 4, 5 and 7 below, parameterised SQL, and a
test for every changed behaviour. Advisory: the directory layout, the
`net/http` mux, `sqlc` and `goose` (use the router, query layer and
migration tool the repository already has; propose a switch in an ADR,
never inside a feature change), and the Makefile targets. Say which
rule was relaxed and why in the review or the report.

## Rules that matter most

1. Thread `context.Context` from the handler down. `context.TODO()` and
   `context.Background()` appear only in `main` and tests.
2. Wrap every error with what you were doing: `fmt.Errorf("load invoice
   %s: %w", id, err)`. Map to a status once, in the handler layer.
3. Handlers parse and validate, call a service, write a response. No SQL, no
   business rules in a handler.
4. Repositories return domain types, never `pgx.Rows`. `SELECT *` is a
   finding.
5. `slog` with a request id on every log line; never log a token, a password
   or a full request body.
6. Tests: table-driven for logic; repository tests against Postgres in Docker
   with a rolled-back transaction; an `httptest` test per route.
7. No global state except the logger set in `main`. No `init()` with side
   effects.
8. `make check` = gofmt check, vet, lint, tests with race detector. CI runs
   the same target.

## Traps a competent change still falls into

Each one passes `make check` in a repository whose handler tests use a
fake store, and fails in production. Check them on every change and review.

- **Tenant scope.** Every query on tenant data ANDs `tenant_id = $n` with
  the whole rest of the WHERE: `tenant_id = $1 AND a OR b` parses as
  `(tenant_id = $1 AND a) OR b` and returns every tenant's rows matching
  `b`. Load and write through the tenant-scoped repository method, never an
  unscoped one kept for batch jobs. A fake that filters by tenant itself proves nothing
  about the SQL.
- **Identifiers are not parameters.** `ORDER BY`, a column or a direction
  from a query parameter goes through an allowlist that maps each documented
  value to a fixed clause. Check each mapped clause against the contract:
  a column that exists under that name, and the documented direction for
  every value, not only the default.
- **State changes are conditional writes.** "Only a pending order can be
  cancelled" is `UPDATE orders SET state = 'cancelled' WHERE id = $1 AND
  tenant_id = $2 AND state = 'pending'`, then check rows affected (or
  `RETURNING`). A read
  in the service followed by an unconditional write loses a concurrent race.
  On zero rows, tell "not yours or missing" (404) from "exists but not in
  that state" (409) with a scoped read; do not map both to one error.
- **Migrations replace what the last migration left.** Before altering a
  constraint, index or column, read every applied migration in order: a
  later file may have renamed the constraint (the 0001 default name is gone)
  or folded another rule into it. Drop it by its current name (`IF EXISTS`
  on a wrong name silently keeps the old rule), carry every rule it
  enforced into the replacement, and write a Down that works once rows only
  the new code can produce exist (or refuses with a message). Applied
  migrations are never edited. A status string is the same in the Go
  constant, the CHECK, every filter switch and the docs.
- **Money.** Integer minor units end to end. `minor/100` truncates the fraction; format
  as `%d.%02d` from the absolute value with the sign in front, never via
  float. Check the documented format (`12.50`) against what the tests
  assert: a test can lock in the wrong value.
- **Bounds and returns.** Every numeric parameter has the documented lower
  and upper bound, and every `writeError` is followed by `return`
  (`limit=-1` must not reach the query).
- **The error mapper against the contract.** Compare the one place that maps
  errors to statuses with the documented error table; a new error path
  inherits a wrong mapping silently. Report a mismatch you find; fix it only
  when your change depends on it, and say so.
- **Typed nil.** A constructor returning `*T` that can be nil, stored in an
  interface field, makes `x != nil` true; the call then panics. Return the
  interface type, or assign only when non-nil.
- **Goroutines from a handler.** A panic in them is not recovered by
  `net/http` and kills the process. `r.Context()` is cancelled when the
  handler returns, so work started from it fails; use
  `context.WithoutCancel` with a timeout, an owner that waits (or a queue),
  and log the error.
- **Streaming responses.** Once the first byte is written the status is
  200; check `rows.Err()` before writing and `csv.Writer.Error()` after
  `Flush`, and log a failure, since the client cannot be told.
- **Scope.** Change only what the request needs. A shared helper (JSON
  rendering, time formatting, error mapping) changed on the way changes
  every route; report the pre-existing defects you saw instead.
- **Say what reached PostgreSQL.** Fake-backed tests never run the SQL. If
  Docker is available, apply the migrations up, run the new statements, try
  the Down, and show the output; otherwise say "not run".

## Commands

Each target is used when the Makefile has it; the command after the
colon is the native form to run without one.

```
make setup    # go mod tidy (both modules); make tools; git hooks
make tools    # GOBIN=bin/tools go -C tools install tool (versions from tools/go.mod)
make dev      # go run ./cmd/api with .env
make check    # gofmt -l . ; go vet ./... ; golangci-lint run ; go test -race ./...
make fix      # gofmt -w . ; golangci-lint run --fix
make migrate  # goose -dir db/migrations postgres "$DATABASE_URL" up
make migrate-verify  # up, snapshot, every Down, up again, diff the schema (CI integration job)
make sqlc     # sqlc generate
```

## Gotchas

- `go test ./...` with `-race` needs cgo on some platforms; the Makefile
  falls back with a printed note, never silently.
- goose migrations run in a transaction by default; `CREATE INDEX
  CONCURRENTLY` needs `-- +goose NO TRANSACTION` at the top of the file.
- sqlc output is generated: never edit it, never review it, regenerate it.
- Tools are pinned with the `tool` directive (Go 1.24 and newer) in
  `tools/go.mod`, a module of its own so golangci-lint's dependencies never
  enter the service's `go.mod` or its govulncheck scan. `go install
  ...@latest` in a Makefile or CI job is a finding: two pipelines a day
  apart lint with different rules. Bump with `go -C tools get -tool
  <package>@<version>` and commit `tools/go.sum`.
- A handler that returns after writing an error without `return` writes
  twice. `golangci-lint` catches some of these; the reviewer catches the
  rest.
