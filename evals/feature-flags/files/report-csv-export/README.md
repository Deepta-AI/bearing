# reportsvc

Serves saved reports to customers of the analytics product, sends each
account a weekly digest email, and archives every report nightly for the
data warehouse.

    make check          # go vet + go test
    go run ./cmd/server # listens on :8080

Configuration comes from the environment. Feature flags are `FLAG_<NAME>`
variables read once at startup by `internal/flags` (see
docs/adr/0002-feature-flags.md and the register in
docs/operations/flags.md). Production settings live in deploy/k8s.yaml.

## Endpoints

- `GET /reports/{id}` report as JSON, with a `links.csv` download link
- `GET /reports/{id}/export.csv` report as CSV
- `GET /healthz`

## Jobs

- weekly digest (Mondays 06:00 UTC, cmd/digest): one email per account
  listing its reports, with a download link and the CSV of each attached.
- nightly archive (01:30 UTC, cmd/archive): every report as CSV to the
  warehouse bucket; the warehouse loads it the same night.
