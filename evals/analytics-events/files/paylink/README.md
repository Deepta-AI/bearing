# paylink

Invoicing for small merchants. A merchant creates an invoice in the app
(`/app/...`), sends it, and the customer (the payer) pays it online from a
link in the email.

Two web shells share one bundle (src/web/main.js):

- the merchant app under `/app/`: logged-in merchants, app chrome, the
  analytics consent banner;
- the payer pages under `/pay/<token>`: no login, no app chrome. The payer
  is not a paylink user; many are outside India, some in the EU.

The token in `/pay/<token>` is the payer's only credential: anyone who holds
the link can see the invoice and pay it. Treat it like a password. The
server never logs it (see `logLine` in src/server/app.js).

Payments go through the payment provider (src/server/provider.js). The
provider sends the payer back to `/pay/<token>?status=success` when the
payer leaves its page; the payment is final only when the provider's
`payment.succeeded` webhook reaches `POST /webhooks/payments`. Webhooks the
provider gave up on are caught by `reconcilePayments` (src/server/reconcile.js),
which the scheduler runs every six hours. A merchant can also mark an
invoice paid by hand when the customer paid in cash or by bank transfer
(`POST /api/invoices/:id/mark-paid`).

Real deliveries from the provider's sandbox are in docs/provider/.

Analytics: docs/adr/0004-analytics-collector.md, docs/analytics/.

No npm dependencies; Node 22.5 or later.

    make check    # node --test (every test/*.test.js)
