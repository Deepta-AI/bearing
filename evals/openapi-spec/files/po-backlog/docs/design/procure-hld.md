# procure: high level design

Version: v1

## 1. Scope

Purchase orders for buyer companies: create, list, view, submit,
approve and cancel. Supplier management and the Tally export are later
releases.

## 2. Components

- `procure-api` (Go, net/http) behind the company API gateway.
- Postgres 16, one schema per environment.
- Keycloak for identity (ADR 0002).

## 3. Interfaces

- Public base path: `/api/v1`, JSON only.
- The contract lives at `api/openapi.yaml` and is the source of truth
  for the web and mobile clients.
- Companies on the pilot hold up to 200,000 purchase orders each, so
  list endpoints must not page by offset.

## 4. Data

`purchase_orders(id, company_id, supplier_id, status, created_by,
approved_by, total_paise, currency, created_at, updated_at)` and
`purchase_order_lines(po_id, line_no, sku, quantity, unit_price_paise)`.
Status is one of draft, submitted, approved, cancelled.
