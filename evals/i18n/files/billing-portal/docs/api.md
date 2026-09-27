# Billing API (the parts the portal uses)

`GET /api/me` returns `{ id, name, email, preferredLocale }`.
`preferredLocale` is a BCP 47 tag the customer chose in their profile
(`en-IN` or `hi-IN` today), or `null` if they never chose.

`GET /api/invoices` returns a list of
`{ id, number, customer, status, issuedAt, dueAt, paidAt, amountPaise }`;
`status` is `open`, `overdue` or `paid`.

`POST /api/invoices/:id/pay` starts a payment.

## Errors

Every error response is

    { "error": { "code": "invoice.already_paid", "message": "Invoice INV-0042 is already paid" } }

`message` is English, written for our logs and support staff, and may
contain internal detail. Clients must not show it to customers; they map
`code` to their own text. Codes in use:

| code | when |
|---|---|
| `invoice.already_paid` | pay on an invoice that is already paid |
| `invoice.not_found` | the invoice id does not exist for this customer |
| `payment.declined` | the payment provider declined |
| `payment.provider_unavailable` | the provider did not answer |
| `auth.session_expired` | the session cookie expired |

Any other code may appear later; clients show a generic message for it.
