# orders-api

Order lookup for the storefront and the support desk. Standard library only.

## Run it

    cp .env.example .env    # then edit
    make dev                # go run ./cmd/api, reads .env

The server listens on `ADDR` (default `:8080`) and starts with a small
in-memory demo store (orders `ord_1001` and `ord_1002`).

## Endpoints

See `docs/api.md`.

## Checks

    make check    # go vet, then go test
