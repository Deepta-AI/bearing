# shopfront

The storefront API: product search and checkout. Go standard library only.

    make check    # go vet + go test
    make run      # listens on $PORT (default 8080)

Routes are registered in internal/httpapi/router.go. Every /v1 route needs
an `X-Api-Key` header with one of the keys in `API_KEYS`; each key is rate
limited (see docs/adr/0003-api-keys-and-rate-limits.md).

This repository slice keeps orders in `orders.MemoryStore`; the Postgres
store is wired in the platform build and is out of scope here.

Environments (URLs in .gitlab-ci.yml): qa and production. qa is sized
down, see docs/adr/0004-qa-environment.md.

## Performance

Target: p95 under 1 s for every route (2025 launch target).

Quick benchmark: `scripts/bench.sh` (needs `hey`).
