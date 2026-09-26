# invoiced

Invoice service for the billing team: creates invoices, applies GST and
charges late fees on overdue invoices.

## Layout

- `internal/invoice`: invoices, line totals, late fees
- `internal/tax`: GST calculation
- `internal/billing`: the monthly billing schedule (fully covered by tests)
- `internal/store`: Postgres persistence
- `cmd/invoiced`: the HTTP entry point

## Tests

`make test` runs the 14 unit tests; `make test-integration` runs the store
tests against Postgres (set `DATABASE_URL`). CI runs `make test` on every
push and has been green since the late fee change.

Test cases and their stories are in `docs/testing/test-cases.md`.

## Load test

`make load-test` runs the k6 smoke test against the environment in
`LOAD_BASE_URL`.
