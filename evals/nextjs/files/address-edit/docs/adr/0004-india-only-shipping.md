# ADR-0004: Ship to India only

Status: Accepted
Date: 2026-07-14
Supersedes: the Sri Lanka pilot (ADR-0002)

## Context

The Sri Lanka pilot ended on 30 June 2026. Courier partners there are gone
and orders to LK addresses cannot be fulfilled.

## Decision

- Delivery addresses are Indian only. `country` is always `IN`; the API
  rejects anything else with 422.
- A PIN code is exactly six digits and does not start with 0.
- A phone number is ten digits starting with 6, 7, 8 or 9 (no +91, no
  spaces); the courier's SMS gateway takes that form only.
- Existing LK addresses stay readable until customers remove them; they
  cannot be saved again unchanged.

## Consequences

Forms and server-side validation in the storefront follow these rules. The
API applies the same rules, but a 422 from the API is a last resort, not
the storefront's validation.
