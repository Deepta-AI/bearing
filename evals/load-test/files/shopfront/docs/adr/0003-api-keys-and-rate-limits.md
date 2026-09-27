# ADR-0003: API keys and per-key rate limits

Status: Accepted (2026-02-20)

## Context

Partner apps and our own web front end call the API. One misbehaving
client took the service down in January.

## Decision

Every /v1 request carries an `X-Api-Key`. Each key has its own token
bucket of `RATE_LIMIT_RPS` requests a second (20 in every environment),
with a burst of the same size. Over the limit the API answers 429 with
`Retry-After: 1`. The web front end holds a pool of keys, one per edge
node, so real traffic is spread across many buckets.

## Consequences

Any client that needs more than 20 requests a second needs more keys or a
raised limit for its key, which is a config change per environment.
