# 0002. Server-rendered pages, no npm dependencies

Status: Accepted (2026-02-11)

## Context

The signup page is our main acquisition path and is often opened from email
clients and corporate browsers with scripts blocked. We were also bitten by a
compromised transitive package in the old front end.

## Decision

- Pages are rendered on the server. Every form, signup included, must be
  completable with JavaScript disabled; public/*.js may only enhance.
- The repository has no npm dependencies, runtime or dev. Adding one, dev
  tooling included, needs a security review ticket (SEC queue) before the
  merge request.
- Tests use node:test only.

## Consequences

No bundler, no framework, no test libraries. Browser-level checks run outside
this repository until a dependency is approved.
