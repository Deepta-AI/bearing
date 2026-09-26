# ADR 0001: PostgreSQL 16 and goose migrations

Status: Accepted (2025-03-04)

## Context

invoice-service needs a transactional store for invoices, lines and payments.

## Decision

- PostgreSQL 16, one database per environment.
- Schema changes are goose migrations in `db/migrations/`, one file per step,
  each with a Down.
- Migrations run from the pre-deploy job (`goose up`) while the previous
  release is still serving traffic. A migration must therefore work with the
  code that is currently deployed, and must not take a lock that blocks
  invoice writes for more than a moment: `SET lock_timeout` before any
  `ALTER TABLE`, and indexes on large tables built `CONCURRENTLY` in a file
  marked `-- +goose NO TRANSACTION`.
- Data fixes and backfills are never part of a migration file.

## Consequences

The pre-deploy job fails the deploy if a migration fails; the on-call engineer
cleans up by hand before the next attempt.
