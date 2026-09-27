# ADR-0001: Postgres is the primary store

- Status: Accepted
- Date: 2026-07-02

## Context

Payments and refunds need transactions and a durable audit trail.

## Decision

Payments, refunds and anything that must survive a restart live in Postgres.
The in-memory store in `internal/refunds` exists for local runs and tests.

## Consequences

Every schema change is a migration under `migrations/`.
