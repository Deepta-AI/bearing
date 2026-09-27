# ledger

Records customer payments and refunds for the shop and answers "what has
this customer paid". One process, one SQLite database file in WAL mode.

## Layout

- `app/db.py`: connection settings.
- `app/payments.py`: record a payment or refund, totals per customer.
- `db/migrations`: goose SQL migrations. The deploy script runs
  `make migrate` on the server, then restarts the app.
- `tests/`: pytest. `tests/migrate.py` applies the goose files with the
  standard library so the tests need no goose binary.
- `docs/`: decisions, operations notes and plans for the next MRs.

## Commands

    make check      # the test suite
    make migrate    # goose up against $(DB_PATH), the production file
