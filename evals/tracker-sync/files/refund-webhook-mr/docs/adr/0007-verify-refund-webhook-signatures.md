# ADR-0007: Verify refund webhook signatures

Status: Proposed

## Context

The refund webhook endpoint is public. Without a check, anyone can post a
refund.updated event and mark a refund as succeeded.

## Decision

Verify the provider's HMAC-SHA256 signature over "<timestamp>.<raw body>" with
the webhook secret, compare in constant time, and reject events whose
timestamp is more than 5 minutes from the server clock.

## Consequences

The raw request body must reach the handler unparsed. The webhook secret is a
deploy-time secret.
