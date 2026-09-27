# Orders API (v1.6)

Maintained by the backend team. Base URL comes from `VITE_API_BASE_URL`. Every
response is JSON; errors are `{ "error": { "code": string, "message": string } }`.

## GET /api/orders

Lists orders, newest first. Filtering and pagination happen on the server.

| Query parameter | Type | Notes |
|---|---|---|
| `page` | integer, from 1 | default 1 |
| `pageSize` | integer, 1 to 100 | default 25 |
| `status` | one of `pending`, `paid`, `shipped`, `cancelled`, `refunded` | optional; an unknown value is a 400 `invalid_status` |
| `q` | string, 3 to 100 characters | optional; matches the start of the customer email, case-insensitive; shorter than 3 characters is a 400 `invalid_query` |

Response 200:

```json
{
  "items": [
    {
      "id": "ord_1042",
      "number": "SO-1042",
      "customerEmail": "asha@example.com",
      "status": "paid",
      "totalPaise": 249900,
      "placedAt": "2026-09-20T10:15:00Z"
    }
  ],
  "page": 1,
  "pageSize": 25,
  "total": 1318
}
```

`total` is the number of orders matching the filters, across all pages. A `page`
past the last one is not an error: it returns 200 with an empty `items` array and
the real `total`.

`q` is matched exactly as sent: the server does not strip whitespace, so
`"asha@example.com "` (a trailing space, common when an address is copied from an
email client) matches nothing.

## GET /api/orders/{id}

One order with the same fields plus `lines`. 404 `not_found` when it does not exist.

## Changelog

- v1.6 (2026-08-28): new status `refunded` for orders refunded after shipping.
  Existing refunds before this date stay `cancelled`.
- v1.5 (2026-06-02): `q` matches the customer email instead of the order number.
