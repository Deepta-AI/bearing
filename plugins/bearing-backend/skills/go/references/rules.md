---
paths:
  - "**/*.go"
---

# Go rules (loaded when a .go file is touched)

- Thread `context.Context`; `TODO()`/`Background()` only in `main` and tests.
- Wrap errors with what you were doing and `%w`; map to status once, in the
  handler layer; never discard an error without a comment saying why.
  An error is logged or returned, never both.
- Handlers: decode with `DisallowUnknownFields`, validate, call a service,
  `writeJSON`/`writeError`. No SQL or business rules in a handler.
- Repositories return domain types; no `SELECT *`; queries parameterised;
  transactions begin in services.
- Every goroutine has an owner and a stop signal. `-race` in `make check`.
- `slog` with request id; never log secrets or full bodies.
- Table-driven tests, `httptest` for routes, Postgres in Docker for
  repositories, no `time.Sleep` on the real clock (inject a clock, or run
  the test inside `synctest.Test`, where time is fake).
- Generated code (`sqlc`, protobuf) is never edited or reviewed by hand.
- No `//nolint` without a task id and a reason on the same line.
