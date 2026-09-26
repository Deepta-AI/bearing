---
name: go
description: 'Conventions for Go services: net/http mux, pgx, sqlc, goose, slog, golangci-lint, table-driven and httptest tests. Use when writing, reviewing or scaffolding "Go" code, "a Go handler" or "sqlc queries".'
allowed-tools: Read, Grep, Glob, Skill, Bash(go build:*), Bash(go test:*), Bash(go vet:*), Bash(gofmt:*), Bash(golangci-lint run:*), Bash(make:*)
---

# go

The Go stack on this standard: Go 1.25 or newer (the templates pin 1.26), standard library `net/http` mux, `pgx` for
PostgreSQL, `sqlc` for typed queries, `goose` for migrations, `slog` for
logs, `golangci-lint` for lint, `govulncheck` in CI.

## Inputs

- Go files: the repository as it is; no scaffold is needed. A
  different layout is handled under "On a foreign layout".
- Gate: `make check` when a Makefile has that target; else the native
  commands under Commands, one by one.
- `references/guidelines.md` and `references/review-checklist.md` ship
  with this skill. `new-repo` and `ci-pipeline` are suggestions for a
  repository without a Makefile or a pipeline, never prerequisites.

## When this skill is active

- Writing or changing `.go` files: apply `references/guidelines.md`. Read it
  once per session, then work.
- Reviewing a diff with Go files: apply `references/review-checklist.md` and
  report in the reviewer format.
- Scaffolding (`new-repo go-api <Name>`): `templates/` holds the skeleton
  and configs; `bin/brg-scaffold` copies them. Do not hand-copy. A
  command-line tool (no server, no database) is `new-repo go-cli
  <Name>` from `templates-cli/`: the standard library, one binary, the same
  gates.
- Generating CI (`ci-pipeline`): `templates/.gitlab-ci.yml` is the source.
- Pack skills (samber/cc-skills-golang), when installed, are deeper than
  this skill on Go itself; load the one the job needs with the Skill
  tool: `golang-concurrency` for goroutines, channels, sync and errgroup;
  `golang-context` for cancellation, deadlines and `WithoutCancel`;
  `golang-error-handling` for error types and the log-or-return rule;
  `golang-testing` for tests (synctest, goleak, fuzzing); `golang-database`
  for pgx repository code; `golang-security` when code touches auth,
  crypto, file paths, outbound URLs or user input; `golang-safety` for
  nil, aliasing and numeric conversions; `golang-observability` for
  metrics and spans, under the names `observability` sets;
  `golang-performance` only after a profile names the hotspot;
  `golang-code-style` for style review.
- This skill explicitly supersedes the pack on the stack: sqlc, goose and
  pgx (not golang-migrate, sqlx or Atlas); schemas and migrations are
  written, via `db-migration` and `database`, and the pack's bans on
  writing schemas and on RLS, triggers and views give way to
  `database`; tools stay pinned in `tools/go.mod` (never the pack's
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
