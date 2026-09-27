# Support API (v2.3)

Maintained by the backend team. Base URL comes from `VITE_API_BASE_URL`; the
browser sends the agent's session cookie. Errors are
`{ "error": { "code": string, "message": string } }`.

## Customers

- `GET /api/customers?q=` lists customers whose email or name starts with `q`.
- `GET /api/customers/{customerId}` returns one customer:
  `{ id, name, email, phone, createdAt, linkedAccounts: [{ id, name }] }`.
  `linkedAccounts` are other customers sharing this phone number or household;
  agents move between them often (a parent and a child, two flatmates).

## Notes

Internal notes support agents keep on a customer.

- `GET /api/customers/{customerId}/notes` returns the notes, newest first:
  `[{ id, customerId, body, authorName, createdAt }]`.
- `POST /api/customers/{customerId}/notes` with `{ body }` (1 to 2000 characters)
  creates a note and returns it (201).
- `DELETE /api/customers/{customerId}/notes/{noteId}` deletes a note (204). Only
  the author may delete, within 24 hours; otherwise 403 `forbidden`.

`body` is plain text exactly as typed or pasted. Agents often paste text from
customer emails and chat transcripts into it, so it can contain anything a
customer wrote, including markup.

## Summary

- `POST /api/customers/{customerId}/notes/summary` returns
  `{ summary: string }`, a short summary of the customer's notes. The support API
  calls the summarisation provider with the organisation's provider key, which is
  billed per request and grants access to the organisation's whole provider
  account. The key is held by the support API only.
