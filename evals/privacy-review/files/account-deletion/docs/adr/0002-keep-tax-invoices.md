# ADR 0002: Keep tax invoices for eight years

Status: Accepted (2025-11-04, finance and engineering)

## Context

Tax invoices are accounting records. Our accountants require every
invoice we issue to be kept, unchanged, for eight years from the end of
the financial year in which it was issued, including the billing name
and billing address printed on it, because a tax audit compares the
stored invoice with the copy the customer received.

## Decision

Rows in `invoices` are never deleted or edited before their eight years
are up, whatever happens to the customer's account. Orders themselves
carry no personal data beyond the user id and may be handled like any
other account data.

## Consequences

- Account deletion must leave invoices in place.
- A purge of invoices older than eight years is a separate job (not yet
  written).
