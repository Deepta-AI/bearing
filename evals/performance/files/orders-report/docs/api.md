# API

## GET /reports/orders

Query: `status` (optional; `paid`, `pending` or `refunded`). Without it,
every order is returned.

Response: a JSON array of rows

    {"order_id": "ord_000123", "created_at": "2026-08-01T10:00:00Z",
     "customer_id": "cus_000042", "customer_name": "Customer 42",
     "status": "paid", "items": 3, "total_cents": 12900}

Contract (the back office and the CSV export depend on it):

- Rows are sorted by `created_at` descending; rows with the same
  `created_at` are sorted by `order_id` ascending.
- An order whose customer has been deleted still appears, with
  `customer_name` set to `(deleted customer)`.
- The report reflects every write that returned before the request
  started: an order created or a customer deleted a moment ago shows up
  in the next report.
- `total_cents` is the sum of quantity times unit price over the items,
  skipping any line whose SKU is not of the form `SKU-0000-X` (a few
  legacy imports carry malformed lines that must not be billed).

## POST /orders

Body: an order (`id`, `customer_id`, `status`, `created_at`, `items`).
201 on success.

## POST /customers

Body: `{"id": "...", "name": "..."}`. 201 on success.

## DELETE /customers/{id}

204. The customer's orders are kept.
