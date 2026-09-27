# Basket API (as the app uses it)

Base URL from `EXPO_PUBLIC_API_URL`. Every request carries
`Authorization: Bearer <access token>`. Errors are
`{ "error": { "code": string, "message": string } }` with a 4xx or 5xx status.

## Money

All amounts are integers in minor units (paise) with a `currency` field,
for example `"total_minor": 124950, "currency": "INR"` is Rs 1,249.50.
Never floats. The v0 rupee field `total` was removed on 2026-06-30.

## Addresses

`GET /v1/addresses` returns `{ "items": Address[] }` (at most 10).

Address: `id` string, `label` string, `line1` string, `city` string,
`pincode` string.

## Orders

Order ids are `ord_` followed by 12 letters or digits, for example
`ord_7Hq2LmX9pR4s`.

### GET /v1/orders

Newest first, cursor paginated.

Query: `limit` (default 20, max 50), `cursor` (from the previous page).

    {
      "items": [OrderSummary, ...],
      "next_cursor": "c_9f2a" | null
    }

`next_cursor` is null on the last page.

OrderSummary: `id`, `placed_at` (ISO 8601 with offset), `status`,
`item_count` integer, `total_minor` integer, `currency` string.

`status` is one of `placed`, `packed`, `out_for_delivery`, `delivered`,
`cancelled`, `refunded`.

### GET /v1/orders/{id}

OrderDetail: every OrderSummary field, plus `delivery_address` (Address),
`delivered_at` (ISO 8601 with offset, null until delivered),
`lines`: array of `{ "sku": string, "name": string, "qty": integer,
"unit_price_minor": integer }`, `delivery_fee_minor` integer,
`discount_minor` integer.

`404` when the order does not exist or belongs to another customer.

## Uploads

### POST /v1/uploads

Body `{ "content_type": "image/jpeg" | "image/png", "size_bytes": integer }`.
Returns `{ "upload_id": string, "upload_url": string, "expires_at": string }`.
PUT the file body to `upload_url` within 10 minutes. Files over 5 MB
(5,242,880 bytes) are refused with 413, both here and at the PUT.

## Returns

A delivered order can be returned within 7 days of delivery.

### POST /v1/returns

Headers: `Idempotency-Key` (required, a UUID generated once per return the
customer submits; a repeat with the same key returns the first result
instead of creating a second return).

Body `{ "order_id": string, "lines": [{ "sku": string, "qty": integer }],
"reason": "damaged" | "missing" | "wrong_item" | "expired",
"photo_upload_ids": string[] }`. `damaged` needs at least one photo.

Returns `201` with `{ "return_id": string, "status": "requested" }`,
`422` when the order is not returnable.

## Changelog

- 2026-06-30: v0 order fields removed (`total` in rupees). Amounts are
  `*_minor` only.
- 2026-04-02: orders list became cursor paginated (was offset).
