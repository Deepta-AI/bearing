# LLD: orders

Status: Accepted (2026-03-10)

## Create an order

1. `POST /orders` decodes the body in `internal/orders/handler.go`.
2. Every create request passes through `ValidateOrder` in
   `internal/orders/validate.go` before it reaches the store: a customer id
   is required and `Cents` must be greater than zero. A request that fails
   validation gets a 422 with the field names.
3. The order is written through `internal/db/orders.go`.

## List orders

`GET /orders` returns every order, newest first.
