# shipments-api

Read API over shipments for the merchant dashboard and the partner
integrations (partners poll `GET /v1/shipments` from their own systems).

## Run

    make run            # listens on :8080, or $ADDR
    make check          # vet and tests

## Endpoints

- `GET /v1/shipments?status=&limit=` lists shipments; `status` is one of
  `created`, `in_transit`, `delivered`; `limit` defaults to 50.
- `GET /v1/shipments/{id}` returns one shipment, 404 when unknown.
- `GET /version` returns the running version.

The contract is `api/openapi.yaml`.

## Versions

The version lives in `VERSION` and `internal/version/version.go`. See
CONTRIBUTING.md for how releases and hotfixes are cut.
