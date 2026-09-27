# Service levels

| Endpoint | Objective |
| --- | --- |
| GET /reports/orders | p95 under 300 ms for the largest tenant, unfiltered |
| POST /orders | p95 under 50 ms |

## Sizing

The largest tenant today (checked 2026-09-01 from the nightly snapshot):

- 60,000 orders, 1 to 5 line items each (3 on average)
- 8,000 customers, about 2% of them deleted with orders kept
- about one line item in 300 carries a malformed legacy SKU (never billed;
  see docs/api.md)

Every other tenant is under a tenth of that. Size any measurement of the
report on the largest tenant; small tenants have never been slow.
