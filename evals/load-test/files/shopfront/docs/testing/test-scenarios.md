# Test scenarios

Last reviewed: 2025-11-02

| Id | Area | Scenario | Type |
|---|---|---|---|
| TS-01 | Search | Search by keyword returns matching products | Functional |
| TS-02 | Checkout | Order with an empty basket is rejected | Functional |
| TS-03 | Checkout | `POST /api/checkout` holds 30 requests a second under 1 s p95 | Performance |
| TS-04 | Search | `GET /api/search?term=` holds 60 requests a second under 1 s p95 | Performance |
