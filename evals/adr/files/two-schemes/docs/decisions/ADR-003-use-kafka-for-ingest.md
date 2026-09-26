# ADR-003: Use Kafka for ingest

Status: Accepted

## Context
Ingest spikes at 9x the daily mean during campaigns.

## Decision
We will buffer events through Kafka before the store.

## Consequences
One more cluster to run.
