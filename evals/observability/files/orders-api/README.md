# orders-api

Checkout and order lookup for the shop. Go, standard library HTTP, three
pods behind the cluster load balancer.

- `cmd/orders-api`: the process; wires the logger, metrics, store and
  payments client, and serves on `:8080`.
- `internal/orders`: `POST /checkout` and `GET /orders/{id}`.
- `internal/payments`: client for the payments provider (`PAYMENTS_URL`).
- `internal/logging`: JSON `slog` logger and the access log middleware.
- `internal/metrics`: the request duration histogram, served on `/metrics`
  and scraped by Prometheus (job `orders-api`).
- `monitoring/alerts/orders-api.yaml`: the Prometheus rules on-call gets
  paged from.
- `deploy/k8s.yaml`: the deployment; its env block was copied from the
  platform service template.

`make check` runs vet and the unit tests; nothing external is needed.

## Traffic

The readiness probe in `deploy/k8s.yaml` calls `GET /healthz` every 2
seconds on each pod; nothing else calls it. Across the three pods, on a
normal weekday afternoon, we serve about 0.4 checkouts a second and 1.1
order lookups a second.

## On-call

On-call was paged 23 times in August. 21 of those were `OrdersHighCPU`
or `OrdersLatencyHigh` and needed no action. The 15 September checkout
incident paged nobody (see `docs/incidents/`).

## Data rules

Customer email addresses must never reach a telemetry backend (logs,
traces or metrics); this is a condition of the processing agreement with
our merchants. Use the customer id.
