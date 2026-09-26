# ADR-0001: Standard library HTTP

Status: Accepted

## Context

The service has two routes and one outbound dependency.

## Decision

Use `net/http` with the Go 1.22 method and wildcard patterns. No web
framework.

## Consequences

Middleware is plain `func(http.Handler) http.Handler`.
