# billing-api

Invoices for the merchant dashboard and the mobile app. Go 1.25, standard
library HTTP, PostgreSQL through `database/sql` (the pgx stdlib driver is
linked in by the deploy build).

## Layout

- `cmd/api`: wiring only.
- `internal/auth`: API key middleware; puts the caller's account id on the
  request context.
- `internal/invoice`: invoice rules. No SQL, no HTTP.
- `internal/store`: SQL for invoices.
- `internal/httpapi`: routes, handlers, JSON helpers.
- `migrations`: goose migrations. 0001 and 0002 are applied in production;
  never edit an applied migration, add a new file.

## API

The contract for clients is `docs/api.md`. Change it in the same MR as the
handler.

## Working on it

    make check   # gofmt, vet, tests with -race

Handler tests use `httptest` with an in-memory repository
(`internal/httpapi/fake_test.go`); there are no database tests yet.
