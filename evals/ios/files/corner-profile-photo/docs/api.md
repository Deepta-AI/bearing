# Corner API (v1)

Base URL from `API_BASE_URL`. Every request sends `Authorization: Bearer
<access token>` and an `X-Request-Id`. JSON keys are snake_case; timestamps
are ISO 8601 in UTC without fractional seconds.

Errors: `401` token missing or expired, `422` invalid parameters (the body
names the field), `5xx` retry later.

## GET /v1/orders

The signed-in customer's orders, newest first.

    [{"id": 90412, "placed_at": "2026-09-20T08:14:00Z", "total_paise": 125099, "status": "delivered"}]

`status` is one of `placed`, `packed`, `out_for_delivery`, `delivered`,
`cancelled`. New values may be added at any time; clients must not fail on
an unknown one.

## POST /v1/me/photo

Sets the signed-in customer's profile photo. `multipart/form-data` with one
part named `photo`, content type `image/jpeg`.

- The part must be at most 2 MB (2,097,152 bytes); larger returns `413`.
- The longer side must be at most 2048 px; larger returns `422` with
  `{"field": "photo", "reason": "dimensions"}`.
- `200` returns `{"photo_url": "https://cdn.corner.example/p/abc.jpg"}`.
- The server stores the part as sent and serves it from the public CDN;
  delivery partners see it on each order.

## GET /v1/stores/nearby

Stores within a radius of a point.

Query parameters:

| name       | type   | notes                                              |
|------------|--------|----------------------------------------------------|
| `lat`      | number | required, degrees                                  |
| `lng`      | number | required, degrees                                  |
| `radius_m` | int    | optional, default 2000, maximum 5000 (422 above it)|

Response `200`:

    {
      "stores": [
        {"id": "st_118", "name": "Corner Indiranagar", "address": "12 100 Feet Rd",
         "distance_m": 412.7, "status": "open"},
        {"id": "st_042", "name": "Corner Domlur", "address": "3 Airport Rd",
         "distance_m": 1650.0, "status": "closing_soon"}
      ]
    }

- The list is returned in no particular order (it comes from a spatial
  index); sort on the client if order matters.
- `distance_m` is metres from the given point, a decimal number.
- `status` is `open`, `closing_soon` or `closed` today. `temporarily_closed`
  is being added next quarter; clients must not fail on an unknown value.
- An area with no stores returns `{"stores": []}`, not 404.
