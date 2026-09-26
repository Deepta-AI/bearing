# payments-core API

All amounts are integer paise. A request for an order of another merchant
returns 404.

An order's `status` is `pending` (card authorised, not yet captured),
`paid` or `cancelled`. Only a `paid` order can be refunded: a `pending`
order holds no captured money and is cancelled instead, which releases the
authorisation.

## GET /orders/{id}

Returns the order.

    200 {"id": 10, "total_paise": 100000, "status": "paid"}
    404 {"error": "order not found"}
