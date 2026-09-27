# ledgerly

Invoicing API for small businesses. Each business is a tenant with its own
API keys; the dashboard signs users in with email and password.

## Routes

| Route | Auth |
| --- | --- |
| `POST /login` | email and password, then redirect to `next` |
| `GET /api/v1/invoices` | API key (`requireAuth`) |
| `GET /api/v1/invoices/{id}` | API key (`requireAuth`) |
| `GET /api/v1/invoices/{id}/pdf` | API key (`requireAuth`) |
| `POST /api/v1/webhooks/payment` | HMAC signature from the payment provider |

Every `/api/v1` route except the payment webhook goes through
`requireAuth`, which resolves the API key to a tenant, and every invoice
lookup is scoped to that tenant.

`make check` runs vet and the tests.
