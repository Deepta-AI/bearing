# 3. Cookie sessions for the web app

Status: Accepted

## Context

The only client is the browser app served from the same origin as the API.

## Decision

We will authenticate with a server-side session: an opaque `sid` cookie
that maps to the principal in internal/auth. No JWTs.

## Consequences

Logout deletes the server-side session. A client that cannot hold
cookies (a native app) needs a separate decision.
