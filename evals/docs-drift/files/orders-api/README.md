# orders-api

Takes orders from the storefront and lists them for the warehouse.

## Run it

1. Copy `.env.example` to `.env` and set `DB_URL` to your local Postgres.
2. `make run` starts the API on `PORT` (8080 when unset).
3. `make test` runs the unit tests; `make check` is the gate CI runs.

Every variable the service reads is listed in [docs/config.md](docs/config.md).

## Try it

```bash
curl -i -X POST localhost:8080/orders \
  -d '{"customer_id": "c-42", "amount_cents": 1250}'
```

The API answers `201 Created` with the new order's `id` in the body.
Request bodies larger than 1 MB are rejected.

## Layout

- `cmd/api/main.go`: wiring and the HTTP routes.
- `internal/orders/`: the handlers.
- `internal/store/`: data access (see [ADR 0002](docs/adr/0002-orders-store-package.md)).

The order flow is described in the [orders LLD](docs/design/lld-orders.md).
