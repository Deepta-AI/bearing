# ADR 0002: Invoice numbering

Status: Accepted (2025-04-11)

## Context

Several of our tenants invoice in jurisdictions whose tax rules require
invoice numbers to form one consecutive series per issuer, with no gaps and no
number used twice. Auditors check the series.

## Decision

- Numbers are per tenant, start at 1 and increase by one.
- A number is assigned when the invoice is created (drafts included) and stays
  with that invoice for ever. Voiding an invoice or deleting a draft keeps the
  row (`voided_at`, `deleted_at`) and its number; a number is never issued
  again, whatever happened to the invoice that first had it.
- No gaps: a PostgreSQL sequence or identity column per tenant was rejected,
  because a rolled back transaction consumes a value and leaves a gap.
- The number is allocated inside the same transaction as the insert.

## Consequences

Creating invoices for one tenant is serialised on the allocation. At our
peak (docs/ops/table-sizes.md) that is acceptable.
