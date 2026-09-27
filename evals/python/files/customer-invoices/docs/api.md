# invoices-api contract

Every request carries `Authorization: Bearer <api key>`. A key belongs to
one organisation; a resource of another organisation answers 404, never
403, so ids cannot be probed.

## Errors

    {"error": {"code": "not_found", "message": "customer cus_123"}}

Validation failures are 422 with code `validation_failed` and the field
errors in `details`.

## Lists

Lists are newest first and paged with an opaque cursor:

- `limit`: 1 to 100, default 20; anything else is a 422
- `cursor`: the `next_cursor` of the previous page
- response: `{"items": [...], "next_cursor": "..." | null}`

## Money

Amounts are decimal strings in the invoice currency, for example
`"amount": "1250.00"` with `"currency": "INR"`.

## Endpoints

| Method | Path                     | Returns                  |
|--------|--------------------------|--------------------------|
| GET    | /customers               | page of customers        |
| GET    | /customers/{customer_id} | one customer             |
| GET    | /invoices/{invoice_id}   | one invoice (not drafts) |
| POST   | /webhooks/payments       | provider events          |
