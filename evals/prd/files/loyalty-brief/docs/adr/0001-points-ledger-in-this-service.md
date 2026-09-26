# ADR-0001: Points are kept by this service, not by the POS

Status: Accepted, 2026-08-04

## Context
The till vendor's POS has no loyalty module we can extend.

## Decision
This service keeps every member's balance and history, fed by the POS
webhooks (sale.completed, sale.refunded).

## Consequences
The customer app reads balances from this service. The POS never holds points.
