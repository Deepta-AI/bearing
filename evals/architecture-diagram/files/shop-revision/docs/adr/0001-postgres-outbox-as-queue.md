# 1. Use a Postgres outbox table as the queue

Date: 2026-02-09

## Status

Accepted

## Context

The api must hand work to background processes without losing it when a
transaction rolls back. Volume is a few thousand messages a day.

## Decision

We will write outbox rows in the same transaction as the business change
and have consumers claim them with SELECT ... FOR UPDATE SKIP LOCKED.

## Consequences

No broker to run. Each consumer claims its own topic; the outbox table
needs a cleanup job for done rows.
