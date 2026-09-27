# invoice-export

Serves `GET /tenants/{tenant}/invoices/export`: every invoice of a tenant,
newest first, as one JSON document that finance teams import into their
ledgers. Production reads from the billing database through
`store.Store`; local runs use the in-memory store.

## Develop

    make check        # go vet and go test
    DEMO_ROWS=1 make run
    curl -s localhost:8080/tenants/demo/invoices/export | head -c 400

`store.Synthetic` builds production-shaped rows for local load checks.

## Limits

Exports are capped at `MaxExportRows` (internal/export/limits.go). Sizing
and targets are in docs/capacity.md; earlier investigations are in
docs/spikes/.
