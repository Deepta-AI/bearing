# 3. Locales for the portal

Status: Accepted

## Context

All customers are in India. Hindi is the first language after English.

## Decision

- The portal's default locale is `en-IN`, not `en-US`: amounts use Indian
  digit grouping (lakh and crore) in every language we ship.
- Locales at launch: `en-IN` and `hi-IN`. Anything else falls back to
  `en-IN`.
- The customer's own choice is `preferredLocale` on `GET /api/me`. It wins
  over the browser's language, which is used only when `preferredLocale`
  is null.
- Money is INR through `Intl.NumberFormat`, never a hand-written symbol or
  prefix.

## Consequences

The portal needs the customer record before it renders any text.
