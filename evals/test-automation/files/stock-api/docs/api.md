# stock-api endpoints

All bodies are JSON.

## GET /items

Every item, ordered by SKU: `[{"sku": "BOLT-M6", "name": "...", "qty": 40}]`.

## GET /items/{sku}

One item, or 404 `{"error": "not_found"}`.

## POST /items

Creates an item from `{"sku", "name", "qty"}`. SKUs are upper case letters,
digits and hyphens. 201 with the item; 400 on a bad body; 409
`{"error": "duplicate_sku"}` when the SKU exists.

## POST /items/{sku}/adjust

Changes the stock by `{"delta": n}` (negative to take stock out). 200 with
the item. 409 `{"error": "insufficient_stock"}` when the stock would go
below zero. When the new stock is below 5 a low stock alert is posted to
the operations webhook.

## DELETE /items/{sku}

Removes an item. 204, or 404 when it does not exist.
