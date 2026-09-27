# Ledger API (the parts the console uses)

Every call sends `Authorization: Bearer <LEDGER_API_KEY>` and
`X-Org-Id: <orgId>`. The key is the console's service credential: it can
read and write every organisation's invoices. The API scopes each call to
the organisation named in `X-Org-Id` and trusts that header completely.

- `GET /invoices` lists the organisation's invoices.
- `GET /invoices/summary` returns `{ outstanding, overdue, paidThisMonth }`
  in paise for the organisation.
- `POST /invoices/{id}/void` voids an issued invoice.
- `POST /invoices/{id}/mark-paid` records a payment.
- `DELETE /invoices/{id}` removes an invoice permanently, whatever its
  status. It exists for drafts.
- `GET /invoices/export.csv` streams every invoice of the organisation.
