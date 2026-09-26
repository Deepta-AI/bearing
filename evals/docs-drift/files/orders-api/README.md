# orders-api

Takes orders from the storefront and lists them for the warehouse.

## Run it

1. Copy `.env.example` to `.env` and set `DB_URL` to your local Postgres.
2. `make run` starts the API on `PORT` (8080 when unset).
3. `make test` runs the unit tests; `make check` is the gate CI runs.

## Layout

- `cmd/api/main.go`: wiring and the HTTP routes.
- `internal/orders/`: the handlers.
- `internal/store/`: data access (see [ADR 0002](docs/adr/0002-orders-store-package.md)).

The order flow is described in the [orders LLD](docs/design/lld-orders.md).
