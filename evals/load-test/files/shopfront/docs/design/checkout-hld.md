# Checkout: high-level design

Status: Accepted (2026-08-12). Supersedes the 1 s target in the README.

## 1. Goal

Customers find a product and place an order in under a minute, including
during the autumn sale that opens on 3 October at 10:00 IST.

## 2. Non-goals

Payments capture (handled by the payments service after the order is
placed), returns, recommendations.

## 3. Flow

A checkout is two product searches (`GET /v1/search`) followed by one
order (`POST /v1/orders`). Reading the order back (`GET /v1/orders/{id}`)
happens on under 5% of checkouts and is not sized separately.

The web front end sends the search box text as the customer typed it
(case and spacing kept). In the 2025 sale about 60% of search requests
carried a query string not seen earlier that day.

## 4. Components

One Go service (this repository) behind the platform ingress. Search is
served from the in-process catalogue with a result cache; orders go to the
order store.

## 5. Data

Orders: id, customer email, items, total in paise, created at.

## 6. Security

API keys per client (ADR-0003), rate limited per key.

## 7. Scale

- Normal day: about 6 checkouts a second at the busiest hour.
- Sale: marketing expects 24,000 checkouts in the first 10 minutes after
  10:00 IST on 3 October, then a decline to twice the normal rate by
  noon. In the 2025 sale, ingress logs show the rate went from normal to
  the full sale rate within 30 seconds of opening.
- Production runs 6 replicas (deploy/production/values.yaml).

## 8. Failure modes

If the order store is slow, `POST /v1/orders` fails with 503 after 2 s so
the client can retry; search keeps working.

## 9. Service levels

| Route | p95 latency | Errors |
|---|---|---|
| `POST /v1/orders` | 400 ms | under 0.5% (5xx and timeouts) |
| `GET /v1/search` | 200 ms | under 0.5% (5xx and timeouts) |

A 429 from the rate limiter is a client error, not a service error.
