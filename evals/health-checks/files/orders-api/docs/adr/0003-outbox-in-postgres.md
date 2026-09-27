# ADR-0003: Order events through a Postgres outbox

Status: Accepted (supersedes ADR-0001, NATS for order events)

## Context

Publishing to NATS after the order commit lost events whenever the
process died between the two. Running NATS for one publisher was also
more than the team wanted to operate.

## Decision

Order events are written to the `outbox` table in the same transaction
as the order. The data team's CDC connector reads the table. orders-api
no longer connects to NATS; the NATS client was removed.

## Consequences

Postgres is the only store orders-api needs to take an order.
