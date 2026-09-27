# 0002. Draft invoices never leave the API

Status: Accepted (2026-04-18)

## Context

Finance staff prepare invoices as drafts, often with wrong amounts, and
the dashboard is shown to people outside finance. A draft that appeared
in a list was once read out to a customer as an amount owed.

## Decision

The API never returns an invoice whose status is `draft`, by id or in any
list, and no filter can ask for drafts. Drafts are edited in the internal
back office, which reads the database directly.

## Consequences

Every invoice query in `app/invoices/repository.py` excludes drafts. The
public status values are `open`, `paid` and `void`.

A draft that is cancelled before it is issued becomes `void` without
ever being issued: it is visible from then on, and its `issued_at` stays
NULL.
