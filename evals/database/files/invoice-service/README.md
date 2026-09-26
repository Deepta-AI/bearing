# invoice-service

Issues and lists invoices for every tenant on the billing platform. Python 3.12,
PostgreSQL 16, migrations with goose.

## Layout

- `app/db/`: repositories; the only place SQL lives.
- `app/services/`: units of work; transactions open and close here.
- `app/http.py`: request handlers (thin).
- `db/migrations/`: goose migrations, `NNNN_name.sql`, each with an Up and a Down.
- `docs/`: ADRs, schema notes, ops notes.

## Running

```
make check          # migration lint + unit tests (no database needed)
make migrate        # goose up against $DATABASE_URL
make migrate-down   # goose down one step
```

Migrations are applied by the pre-deploy job (`goose up`) while the previous
release is still serving traffic; see docs/adr/0001-postgres-and-goose.md.
