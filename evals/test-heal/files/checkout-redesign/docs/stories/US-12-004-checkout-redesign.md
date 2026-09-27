# US-12-004 Checkout redesign

As a shopper I want the order summary beside my items and a clear primary
action, so that I can check what I pay before I place the order.

## Acceptance criteria

1. The order summary (coupon, shipping, total) sits in a side panel
   labelled "Order summary".
2. The primary action reads "Place order" (it was "Pay now") and carries
   `data-testid="place-order"` for tests.
3. A "Save for later" button and a "Back to cart" link sit beside it.
4. Below the free shipping threshold the summary says how much more to
   add for free shipping.
5. Nothing else about checkout behaviour changes: pricing, coupons, the
   free shipping rule and when the primary action is available stay as
   they are (docs/testing/test-cases.md).
