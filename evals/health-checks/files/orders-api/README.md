# orders-api

Takes and serves shop orders. Go, standard library only.

- Postgres holds orders and the event outbox (see docs/adr/0003).
- Redis caches order reads; on a cache error the handler reads Postgres.
- pricing-api quotes line prices; when it is unavailable the order is
  priced at the catalogue list price carried in the request.

The Postgres driver is linked only in the image build (`-tags pgx`, see
cmd/api/driver_pgx.go); unit tests use fakes.

    make check   # go vet + go test
    make build   # binary with the git sha as main.version

Outside the cluster, the storefront status page (owned by the web team)
polls `https://orders.shop.example/health` once a minute and shows orders
as down on any non-200 answer.

Deployed with kustomize: `k8s/overlays/qa` (the base, 3 replicas) and
`k8s/overlays/prod` (6 replicas, patched probes); CI applies the overlay,
never the base directly.
