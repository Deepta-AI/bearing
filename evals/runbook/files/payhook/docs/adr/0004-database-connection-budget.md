# ADR-0004: Database connection budget

Status: Accepted (2026-05-11)

## Context

The shared Postgres cluster gives each service role a hard connection limit.
The `payhook` role is limited to 20 connections; a connection past the limit
is refused, and the worker treats a refused connection as a crash and
restarts.

## Decision

Every payhook process opens a pool of `DB_POOL_SIZE` connections (4 today).
The sum over all API and worker replicas must stay at or under 20. Scaling
either deployment means lowering `DB_POOL_SIZE` or asking the database team
to raise the role limit first.

## Revisit when

Sustained event volume needs more worker throughput than the budget allows.
