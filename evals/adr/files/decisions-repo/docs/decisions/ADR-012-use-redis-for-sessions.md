# ADR-012: Use Redis for sessions

Status: Accepted (2025-11-03)

## Context
Login sessions need a 12 hour expiry and are read on every request. The
team wanted TTL handled by the store.

## Decision
We will keep sessions in Redis with a key per session and a 12 hour TTL.

## Alternatives considered
- Postgres table with a cleanup job: rejected, the cleanup job was one
  more thing to run.
- Signed stateless cookies: rejected, no server-side revocation.

## Consequences
A managed Redis instance in every environment, used only for sessions.
