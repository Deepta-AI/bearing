# ADR 0004: Online migrations

Status: Accepted (March 2025)

## Context

Migrations run from the pre-deploy job (`make migrate`) while the previous
release is still serving traffic. In February 2025 an `ALTER TABLE invoices`
queued behind the nightly report's read transaction and, while it waited for
its ACCESS EXCLUSIVE lock, blocked every write to invoices for 9 minutes.

## Decision

1. Every migration that alters an existing table starts with
   `SET lock_timeout = '3s';` so a blocked ALTER fails fast and the deploy
   retries, instead of stalling the table.
2. Indexes on any table over one million rows are built with
   `CREATE INDEX CONCURRENTLY` in a file of their own marked
   `-- +goose NO TRANSACTION`. Their Down uses `DROP INDEX CONCURRENTLY`.
3. The previous release must keep working against the new schema: add
   columns nullable (or with a constant default), never rename or drop in
   the same release, never add NOT NULL to a populated column in one step.
4. Every migration has a Down.

## Consequences

Some changes take two or three releases.
