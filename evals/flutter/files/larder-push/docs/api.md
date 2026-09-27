# Larder API (mobile)

Base URL from `API_BASE_URL`. JSON everywhere. Errors are
`{"error": {"code": "...", "message": "..."}}` with a 4xx or 5xx status.

## Changelog

- v2 (March 2026): every amount is an integer in minor units (`*_minor`,
  paise for INR) next to a `currency` code. The v1 decimal fields
  (`price`, `total`) are removed.

## Cart

`GET /cart`

```json
{
  "currency": "INR",
  "items": [
    {"sku": "atta-5kg", "name": "Whole wheat atta 5 kg", "quantity": 1, "unit_price_minor": 28900}
  ]
}
```

`POST /cart/items` with `{"sku": "...", "quantity": 1}` adds to the cart
and returns the cart.

## Orders

`GET /orders?limit=20&cursor=<cursor>`

Newest first. `limit` defaults to 20 and is capped at 20. `next_cursor`
is null on the last page; pass it back as `cursor` for the next page.

```json
{
  "items": [
    {
      "id": "ord_8f2k1q",
      "placed_at": "2026-09-21T18:42:10Z",
      "status": "delivered",
      "item_count": 7,
      "total_minor": 125099,
      "currency": "INR"
    }
  ],
  "next_cursor": "c_20"
}
```

`status` is one of `placed`, `packed`, `out_for_delivery`, `delivered`,
`cancelled`.

`POST /orders/{id}/reorder`

Adds the items of a past order to the current cart, at today's prices.
The request is not idempotent: every call adds the items again. Send an
`Idempotency-Key` header (any unique string, reused for retries of the
same attempt); a repeated key within 24 hours returns the first response
and adds nothing.

Returns 200:

```json
{
  "added": [{"sku": "atta-5kg", "name": "Whole wheat atta 5 kg", "quantity": 1}],
  "unavailable": [{"sku": "paneer-200g", "name": "Paneer 200 g"}]
}
```

Items that are out of stock or discontinued are listed in `unavailable`
and not added. 404 `order_not_found` for an unknown id.

## Devices

`POST /devices` with `{"token": "...", "platform": "android" | "ios"}`
registers a push token for the signed-in user (upsert by token, so a
repeat is harmless). Authenticated with the user's session like every
other call.

Push payloads for order updates carry
`{"type": "order_update", "order_id": "ord_8f2k1q"}` in the data map.
