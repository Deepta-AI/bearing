# storefront

The customer-facing shop: catalogue, cart and the customer account area.
Next.js App Router. Data comes from the commerce API (docs/backend-api.md);
this app has no database of its own.

## Running

    pnpm install
    cp .env.example .env.local   # fill API_TOKEN and SESSION_SECRET
    pnpm dev

Checks: `pnpm lint`, `pnpm typecheck`, `pnpm test`.

## Account area

`/account/profile` lets a customer change their name. `/account/addresses`
lists saved delivery addresses (read only for now).

We ship to India and Sri Lanka, so an address postcode is free text of up
to 10 characters and the country is one of IN or LK.
