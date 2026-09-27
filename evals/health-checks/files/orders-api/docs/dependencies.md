# Dependencies

| Dependency | Used for | If it is down |
| --- | --- | --- |
| Postgres | orders, outbox | orders cannot be taken or read |
| Redis | read cache for GET /orders/{id} | reads go to Postgres |
| pricing-api | line price quotes | list price from the request is used |

pricing-api is owned by the catalogue team. It serves `GET /healthz`
(process up) and `GET /readyz` (its own database and the third-party tax
service it calls). Business endpoint: `GET /v1/quotes/{sku}`.

## Capacity

Each pod's `database/sql` pool is capped at 20 open connections
(cmd/api/main.go). Postgres allows 250; prod runs 6 replicas and the
nightly batch holds 40. During the evening peak every pod sits at the
cap for minutes at a time and requests queue for a connection while
Postgres itself stays healthy (INC-401, 14 August 2026).
