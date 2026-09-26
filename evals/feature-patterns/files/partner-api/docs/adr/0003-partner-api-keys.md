# 3. Partner API keys

Status: Accepted

## Context

Partners integrate server to server; there is no end user in the loop.

## Decision

We will issue one API key per partner from POST /v1/auth/token (client
credentials) and resolve it to a partner id on every request.

## Consequences

Everything a partner does is attributable to its partner id.
