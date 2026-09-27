# 2. Money is integer minor units, formatted in one place

Status: Accepted (2026-05-18)

## Context

The API moved every amount to integer paise (`*_minor`). Floats in rupees
had produced totals like Rs 1249.4999999.

## Decision

Amounts stay integers in minor units everywhere in the app. The only
conversion to display text is `formatMoney(minor, currency)` in
`src/lib/money.ts`.

## Consequences

No component divides by 100 or builds a currency string itself.
