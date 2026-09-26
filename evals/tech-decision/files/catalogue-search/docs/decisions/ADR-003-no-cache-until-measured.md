# ADR-003: No cache layer until measured

Status: Accepted (2025-06-18)

## Context
A Redis cache for the catalogue page was proposed before launch. The page
p95 in load tests was 120 ms against a 300 ms target.

## Decision
We will not add a cache in front of the catalogue page. We will revisit
when the production p95 of GET /catalogue exceeds 300 ms for a week.

## Consequences
One less managed service. Every catalogue read hits Postgres.
