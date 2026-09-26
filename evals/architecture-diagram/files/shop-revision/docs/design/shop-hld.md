# Shop high-level design

Version: v2 (2026-04-20)

## 1. Scope

Customer storefront, order placement, order confirmation emails and the
staff order list.

## 2. Components

- web: React single-page app served by nginx.
- api: Go HTTP service, the only writer to Postgres.
- worker: sends order confirmation emails from the outbox (ADR 0001).

## 3. Integrations

- Razorpay: capture of authorised payments (api).
- Postmark: outbound email over SMTP (worker, production).

## 4. Data

- Postgres 16: orders, carts (system of record), outbox.
- Redis: cart cache in front of Postgres, 7 day TTL (ADR 0002).

## 5. Open questions

- Inventory reservation: INVENTORY_URL points at the warehouse service,
  but no call is implemented yet.
