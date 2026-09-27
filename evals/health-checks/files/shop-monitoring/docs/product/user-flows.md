# Critical user flows

1. Browse and search the catalogue (catalog-api `GET /catalog/products`,
   `GET /catalog/search?q=`).
2. Add to cart (checkout-api `POST /checkout/carts`,
   `POST /checkout/carts/{id}/items`).
3. Check out and pay (checkout-api `POST /checkout/carts/{id}/checkout`):
   charges the card and creates the order.
4. Order history (checkout-api `GET /checkout/orders`).

All checkout-api routes need a customer bearer token.
