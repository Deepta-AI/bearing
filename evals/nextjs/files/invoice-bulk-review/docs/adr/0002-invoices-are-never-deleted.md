# ADR-0002: Issued invoices are voided, never deleted

Status: Accepted
Date: 2026-03-02

## Context

Tax rules require every issued invoice, including cancelled ones, to be
kept for eight years with its number, so the numbering has no gaps.

## Decision

The console never calls `DELETE /invoices/{id}` for an invoice whose
status is not `draft`. Cancelling an issued invoice is `POST
/invoices/{id}/void`, which keeps the record and marks it void.

## Consequences

Any "remove" or "delete" control on issued invoices is a void. Draft
invoices may be deleted.
