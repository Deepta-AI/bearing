# 0004. Hold mods.example.com/money at v1.6.x

Status: Accepted (2026-06-12)

## Context

money v1.7.0 changed `Percent` from half-up to half-even (banker's)
rounding. Our GST invoices must round half-up to the paisa, and invoices
already issued were computed that way; a change in rounding changes totals
the ERP has already booked.

## Decision

Stay on money v1.6.x. Do not accept a v1.7 or later bump, from a person or
a bot, until finance signs off on the rounding change and we have a plan
for invoices already issued.

## Consequences

`internal/billing` keeps a test that pins half-up rounding. Revisit when
finance confirms the rounding rule for FY 2027-28.
