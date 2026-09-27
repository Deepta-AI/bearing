# orders-api: high-level design

Status: Approved (2026-05-20)

## 1. Context

orders-api serves the storefront's product pages and takes orders. It sits
behind the ingress in the `orders-<env>` namespace, three replicas in every
environment.

## 2. Components

| Component | Role | Notes |
| --- | --- | --- |
| orders-api | HTTP API: `GET /products/{id}`, `POST /orders`, `GET /healthz` | stateless, 3 replicas |
| Postgres | products and orders, system of record | see deployment.md |
| Redis | product read cache, 10 minute TTL | cache only, safe to lose |
| PSP | card authorisation before an order is stored | external, EU region |

## 3. Request flow

Product reads check Redis first and fill it from Postgres on a miss. An order
reads the product price from Postgres, authorises the card with the PSP, then
inserts the order row with the PSP auth id.

## 4. Failure modes

| Failure | What the user sees | Alert | Recovery |
| --- | --- | --- | --- |
| Postgres unavailable | `POST /orders` returns 503 with `Retry-After: 5`; product pages keep working from Redis for cached products | `OrdersDBUnavailable` pages on-call within 1 minute | the pool reconnects within 30 s of Postgres coming back; no pod restarts |
| Redis unavailable | product reads fall back to Postgres, p95 under 300 ms; orders unaffected | `OrdersCacheDown` (warning, no page) | automatic when Redis returns; cache refills on read |
| PSP slow or down | `POST /orders` fails fast with 502 after at most 5 s; no order row is written | `OrdersHighErrorRate` | automatic when the PSP recovers |

## 5. Capacity

Peak is about 120 requests a second, 90 percent product reads. Postgres is
sized for all reads with a cold cache.
