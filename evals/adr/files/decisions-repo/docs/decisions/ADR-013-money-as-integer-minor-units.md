# ADR-013: Store money as integer minor units

Status: Accepted (2026-01-20)

## Context
Floating point totals drifted by a paisa on 0.3% of invoices in the
January reconciliation.

## Decision
We will store every amount as a bigint of minor units with an ISO 4217
currency column.

## Alternatives considered
- numeric(19,4): rejected, every client must still round consistently.

## Consequences
Every API field is an integer; display formatting moves to the clients.
