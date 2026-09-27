# ADR-0001: Postgres is the primary store

Status: Accepted, 2026-07-10

## Decision
All maintdesk data lives in one Postgres 16 database. Files (photos,
invoices) do not go in the database; when we need them they go to an
S3-compatible bucket, which we do not run yet.

## Consequences
Any story that stores files first needs the bucket provisioned and a
retention rule agreed.
