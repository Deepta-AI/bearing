# ADR-0002: Stack skills live in their family plugin

Status: Accepted

## Context

Teams that never write Go were loading Go conventions because they sat in
the required plugin.

## Decision

`plugins/bearing` holds only stack-neutral workflow skills. A skill that
is about one language, framework or platform goes in `bearing-backend`
(services: Go, Python) or `bearing-apps` (clients). A stack skill that
needs a workflow step names it with the `bearing:` prefix.

## Consequences

Installing only `bearing` gives a team the workflow with no stack rules.
