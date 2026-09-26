# 0001. Postgres is the ledger's store

Status: Accepted (2026-03-02)

## Context

Postings must be applied exactly once per reference and balances must be
consistent under concurrent writers.

## Decision

Postgres 16. A unique constraint on `postings.reference` makes a repeated
posting a no-op. Schema changes are plain SQL files in `migrations/`,
applied in name order by `scripts/migrate.py`; no migration framework.

## Consequences

The integration tests need a real Postgres with the migrations applied.
