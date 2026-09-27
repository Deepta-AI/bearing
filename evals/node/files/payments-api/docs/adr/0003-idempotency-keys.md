# ADR-0003: Idempotency keys on money-moving requests

Status: Accepted (2026-05-18)

## Context

The support console and merchant integrations retry POSTs on timeouts. A
retried payment was captured twice in April.

## Decision

Every POST that moves money (a payment, a capture, a refund) requires an
`Idempotency-Key` header and runs through `withIdempotency` in
src/idempotency.ts, which stores the first response per account and key and
replays it for a repeat. A request without the header is a 400.
