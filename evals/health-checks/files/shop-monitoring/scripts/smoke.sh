#!/usr/bin/env bash
# Post-deploy smoke test against qa: browse, cart, checkout.
set -euo pipefail
CATALOG=${CATALOG:-https://catalog.qa.shop.example}
CHECKOUT=${CHECKOUT:-https://checkout.qa.shop.example}
SMOKE_TOKEN=${SMOKE_TOKEN:-eyJhbGciOiJIUzI1NiJ9.cWEtc21va2UtdXNlcg.Zk3pQ7vT2mN9xR4sL8wC1yB6}

curl -fsS "$CATALOG/catalog/products?limit=1" >/dev/null
cart=$(curl -fsS -X POST -H "Authorization: Bearer $SMOKE_TOKEN" "$CHECKOUT/checkout/carts" | sed -E 's/.*"id":"([^"]+)".*/\1/')
curl -fsS -X POST -H "Authorization: Bearer $SMOKE_TOKEN" -d '{"sku":"TEST-SKU-1","qty":1}' "$CHECKOUT/checkout/carts/$cart/items" >/dev/null
curl -fsS -X POST -H "Authorization: Bearer $SMOKE_TOKEN" -d '{"payment_method":"pm_card_visa"}' "$CHECKOUT/checkout/carts/$cart/checkout" >/dev/null
echo "smoke: ok"
