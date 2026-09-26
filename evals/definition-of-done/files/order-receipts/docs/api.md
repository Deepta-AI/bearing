# orders-api reference

All responses are JSON. Errors are `{"error": "<code>"}`.

## GET /v1/orders/{id}

The order with that id.

- 200: `{"id", "customer_id", "status", "total_paise", "lines": [...]}`
- 404: `{"error": "not_found"}`

## GET /v1/orders/export/{format}

Every order, for the support desk. `format` is `csv`; anything else is a 404.

- 200: `text/csv` with the header `id,customer_id,status,total_paise`
- 404: `{"error": "not_found"}`

## GET /healthz

- 200: `{"status": "ok"}`
