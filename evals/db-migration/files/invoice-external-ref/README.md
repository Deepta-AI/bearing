# billing

Invoices for every tenant, and the webhook that the payment provider calls
when an invoice is paid.

## Layout

- `internal/invoices`: the invoice store (Postgres, `database/sql`).
- `internal/webhooks`: the payment provider's callback handler.
- `db/migrations`: goose SQL migrations, sequential numbers
  (`goose create <name> sql` then `goose fix`). The latest is `00012`.
- `docs/adr`: decisions. Read 0004 before writing a migration.
- `docs/capacity.md`: table sizes.

## Commands

    make check            # go vet and go test
    make migrate          # goose up against $(DATABASE_URL)
    make migrate-status

There is no local database in this repository; the integration suite runs
in CI against a Postgres 16 service container.
