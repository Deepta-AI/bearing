# ADR-001: Python with plain SQL

Status: Accepted (2025-03-04)

## Context
Two developers, both strongest in Python. The queries are simple and
performance-sensitive.

## Decision
We will write the service in Python with psycopg and hand-written SQL, no ORM.

## Consequences
Queries are reviewed as SQL. Migrations are numbered SQL files in `migrations/`.
