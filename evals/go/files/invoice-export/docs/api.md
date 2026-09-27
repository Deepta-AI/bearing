# billing-api contract

Every request carries `X-API-Key`. The key belongs to one merchant account
and a caller only ever sees or changes that account's invoices. An invoice of
another account answers 404, exactly as a missing one does.

## Conventions

- Amounts are integers in paise (`amount_paise`).
- Times are RFC 3339 in UTC.
- Request bodies are JSON, at most 1 MiB; unknown fields are rejected.
- List responses are `{"items": [...]}`; `items` is always an array, never
  null.

## Errors

    {"error": {"code": "<code>", "message": "<text for a person>"}}

| Status | code            | When                                            |
|--------|-----------------|-------------------------------------------------|
| 400    | invalid_request | the body or a parameter is malformed or missing |
| 401    | unauthorized    | no key, or an unknown key                       |
| 404    | not_found       | no such invoice for this account                |
| 409    | invalid_state   | the invoice's status does not allow the action  |
| 500    | internal        | anything else; the message says nothing more    |

## Invoice lifecycle

    draft -> open -> paid

Only an open invoice can be paid.

## Routes

- `GET /invoices?status=open` lists the account's invoices, newest first.
- `GET /invoices/{id}` returns one invoice.
- `GET /invoices/export?status=open&sort=due_on&limit=1000` downloads the
  account's invoices as CSV (`text/csv`) with the columns number, amount,
  status, due_on. `amount` is in rupees with two decimals (`1250.00`).
  `sort` is one of `created_at` (the default, newest first), `due_on` or
  `amount`; `limit` defaults to 1000 and is at most 5000.
- `POST /invoices/{id}/pay` marks an open invoice paid (manual payments
  recorded by the merchant).
