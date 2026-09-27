# ADR-0001: No runtime dependencies

Status: Accepted (2026-03-02)

## Context

The service handles invoices for every account. A security review after a
compromised transitive package in another team's service asked for the
smallest possible supply chain.

## Decision

The service uses only Node's built-in modules at runtime and in tests:
`node:http`, `node:sqlite`, `node:test`. Validation goes through
src/validate.ts. Adding any npm package (a framework, a validator, an ORM)
needs a new ADR approved by the platform group first; it is never done inside
a feature change.

## Consequences

We keep a small hand-written router and validator. Node 22.18 or later is
required for type stripping.
