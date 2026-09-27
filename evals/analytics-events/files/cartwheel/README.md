# cartwheel

Grocery delivery. Three codebases in one repository:

- `web/`: the storefront (plain ES modules, rendered in the browser);
- `mobile/`: the React Native app (built by the mobile pipeline, not by
  `make check`);
- `server/`: the API (orders, signup).

Product analytics go to our collector (`/collect`) through one analytics
module per codebase. The events are designed in
docs/analytics/EVENT_SHEET.md; docs/analytics/tracking-plan.md has the
identity and consent rules.

The data team builds the funnels from the warehouse. The checkout funnel
is: `cart_viewed` -> `checkout_started` -> `payment_submitted` ->
`order_placed`, split by platform.

    make check    # node --test: web/test and server/test
