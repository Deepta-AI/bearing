# ADR-0002: The loyalty service and app take no payments

Status: Accepted, 2026-08-04

## Context
Money is handled only at the till, which is already PCI assessed. Taking
payments in the app would bring the app and this service into that scope.

## Decision
Neither this service nor the customer app accepts or stores any payment.
Customers pay at the till only.

## Consequences
Anything that needs a customer to pay goes through the till.
