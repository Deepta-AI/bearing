# API conventions

These hold for every endpoint. The dashboard and two customer integrations
depend on them.

## Authentication and scope

Every request carries `x-api-key`. The key belongs to exactly one account and
every resource is scoped to that account. A resource that exists but belongs
to another account answers 404 `not_found`, exactly as if it did not exist,
so ids cannot be probed.

## Lists

- Cursor pagination only. Query `limit` (default 20, minimum 1, maximum 100)
  and `cursor` (opaque, taken from the previous page's `nextCursor`).
- A `limit` outside 1..100 or a cursor that does not decode is a 400
  `validation_error`; it is never clamped silently.
- Newest first: ordered by `created_at` descending, then `id` descending, so
  rows created in the same millisecond still page stably.
- Body: `{ "items": [...], "nextCursor": "<string>" | null }`.

## Money

Amounts are integer minor units with their currency:
`{ "amountMinor": 1250, "currency": "EUR" }`. Never a float, never a
formatted string.

## Invoices

Draft invoices are internal working copies. The API never returns an invoice
whose status is `draft`; only `open`, `paid` and `void` are visible.

## Errors

`{ "error": { "code", "message", "requestId" } }`, with the status from
src/errors.ts. Every response carries `x-request-id`.
