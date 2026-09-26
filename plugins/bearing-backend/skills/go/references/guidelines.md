# Go guidelines

## Project shape

- One binary per `cmd/<name>`; everything else under `internal/` so nothing
  outside the module can import it.
- Packages are named for what they provide (`invoice`, `store`, `httpapi`),
  never `utils`, `common`, `helpers`, `models`.
- A package under 2,000 lines with one reason to change. Split by domain,
  not by layer, once it grows.

## Errors

- Return errors; never panic outside `main` and tests.
- Wrap with context at each layer boundary: `fmt.Errorf("op detail: %w",
  err)`. The chain reads like a stack trace.
- Sentinel errors (`var ErrNotFound = errors.New(...)`) live in the domain
  package; handlers map them with `errors.Is` to status codes in one place.
- Never `_ = err`. If an error is genuinely ignorable, a comment says why.
- An error is logged or returned, never both. The layer that handles it
  (the handler mapping it to a status, or `main`) logs it once; a log
  line followed by a return writes the same failure two or three times.

## HTTP

- Standard library mux with method patterns: `mux.HandleFunc("GET
  /invoices/{id}", h.getInvoice)`.
- Middleware order: recover, request id, logging, auth, then routes.
- Decode request bodies with `json.NewDecoder(r.Body)` and
  `DisallowUnknownFields()`; validate before use; reject bodies over a size
  limit with `http.MaxBytesReader`.
- Responses through one `writeJSON(w, status, v)` helper; errors through one
  `writeError`. Never `w.Write` raw JSON in a handler.
- Timeouts on the server (`ReadHeaderTimeout`, `ReadTimeout`,
  `WriteTimeout`, `IdleTimeout`) and on every outbound client.
- Graceful shutdown on SIGINT and SIGTERM with a bounded context.

## Database

- `pgxpool` created in `main`, passed down. Repositories take a `DBTX`
  interface so they work inside a transaction.
- `sqlc` for every query that can be static. Dynamic queries are built with a
  builder that parameterises, never string concatenation.
- Transactions begin in the service, not the repository.
- Migrations: `goose`, one concern per file, a working Down, an index
  decision comment for every new filter.

## Concurrency

- Every goroutine has an owner that waits for it (`errgroup` or a
  `sync.WaitGroup`) and a way to stop (context).
- Channels are closed by the sender. Buffered channels have a documented
  bound.
- `-race` in `make check`; a race is a failure, not a flake.

## Configuration

- `internal/config` reads environment variables with typed defaults and
  fails fast on missing required ones, printing every missing name at once.
- `.env.example` lists every variable with a placeholder.

## Logging and observability

- `slog` JSON handler in production, text in development. Request id, route,
  status and duration on every request log.
- `/healthz` (process up) and `/readyz` (dependencies reachable) on every
  service. Metrics on `/metrics` when Prometheus is in use.

## Testing

- Table-driven tests with named cases. `t.Parallel()` where the test allows.
- `httptest` for handlers; `testcontainers` or `docker compose` Postgres for
  repositories, each test in a rolled-back transaction, behind
  `//go:build integration` so `make test` stays offline and
  `make test-integration` runs them.
- Golden files only for serialised output that reviewers read on change.
- No `time.Sleep` on the real clock. Inject a clock, or run the test
  inside `synctest.Test` (Go 1.25), where `time.Sleep` advances a fake
  clock and timers, deadlines and context cancellation are deterministic.
- Packages that start goroutines check for leaks with
  `goleak.VerifyTestMain`.

## Style

- `gofmt` and `golangci-lint` decide style. Nothing is discussed in review
  that a tool decides.
- Doc comments on every exported identifier, starting with its name.
- Receivers are one or two letters, consistent per type.
- Accept interfaces, return structs. Define the interface where it is used.
