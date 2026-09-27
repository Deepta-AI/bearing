# ADR-0001: Postgres as the analytics store

Status: Accepted (March 2026)

## Decision

The warehouse is a Postgres 16 database. dbt runs on `dbt-postgres`;
incremental models use `delete+insert`.

## Consequences

A second warehouse, or a move to a columnar store, needs a new ADR.
