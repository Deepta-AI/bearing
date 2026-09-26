# 0001. Postgres as the primary store

Status: Accepted (2024-02-12)

## Context
Tickets, queues and assignments need transactions and reporting.

## Decision
We will keep all helpdesk data in the shared Postgres 16 cluster.

## Consequences
No second datastore without a new ADR.
