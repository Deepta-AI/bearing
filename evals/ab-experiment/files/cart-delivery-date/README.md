# shop-web

Server-rendered storefront for the shop: product pages, cart and checkout.
Mobile and desktop browsers are served by the same routes; `src/routes/cart.js`
switches layout on the user agent.

## Numbers people ask for

- Checkout conversion is around 30% of cart viewers.
- About 10k people view a cart each week.

## Experiments

Percentage rollouts and experiments go through `src/flags.js` and
`config/flags.json`. The flag list with owners is in
`docs/operations/flags.md`; sales and change freezes are in
`docs/operations/calendar.md`. Events are described in
`docs/analytics/EVENT_SHEET.md`; the weekly funnel export the analytics team
refreshes on Mondays is `docs/analytics/funnel-weekly.csv`, and
`docs/analytics/mobile-cart-reach.csv` counts distinct mobile devices over
trailing windows (computed from raw events, so six weeks at most).

## Development

    make check
