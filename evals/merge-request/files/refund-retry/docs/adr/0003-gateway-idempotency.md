# 3. Idempotency keys on every gateway call that moves money

Status: Accepted

## Context

The gateway times out under load and a timed out call may still have been
applied. A blind retry can refund a customer twice.

## Decision

Every refund or capture sends an idempotency key derived from the order
(`refund:<order id>`). A retry reuses the same key, so the gateway applies
the operation at most once.

## Consequences

Retries are safe only while the key stays the same across attempts.
