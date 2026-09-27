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
`lines`: array of `{ "sku": string, "name": string, "qty": integer,
"unit_price_minor": integer }`, `delivery_fee_minor` integer,
`discount_minor` integer.

`404` when the order does not exist or belongs to another customer.

## Changelog

- 2026-09-12: order status `partially_refunded` added, for orders where some
  lines were refunded and the rest delivered.
- 2026-06-30: v0 order fields removed (`total` in rupees). Amounts are
  `*_minor` only.
- 2026-04-02: orders list became cursor paginated (was offset).
