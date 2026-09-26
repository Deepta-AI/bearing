# ADR-014: Idempotency keys on payment POSTs

Status: Accepted (2026-04-08)

## Context
Mobile retries created 41 duplicate payments in March.

## Decision
We will require an Idempotency-Key header on POST /payments and keep keys
for 24 hours in Postgres.

## Alternatives considered
- Deduplicate on amount and timestamp: rejected, false positives on
  legitimate repeat payments.

## Consequences
Clients must generate a key per attempt; the keys table needs a daily
purge, run by the existing jobs worker.
