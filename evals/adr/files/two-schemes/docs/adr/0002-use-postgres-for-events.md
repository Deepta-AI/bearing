# 2. Use Postgres for events

Date: 2025-02-10

## Status
Accepted

## Context
Early volume was under a million events a day.

## Decision
We will store raw events in a partitioned Postgres table.

## Consequences
Dashboards query the raw table directly.
