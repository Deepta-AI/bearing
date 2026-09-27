---
name: go
description: 'Go house rules for services: net/http mux, pgx, sqlc, slog, table-driven and httptest tests, and a route-auth check. Use when asked for "a Go handler", "a new Go service" or changing any Go code.'
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(go test:*), Bash(go vet:*), Bash(make check:*), Bash(python3 ${CLAUDE_PLUGIN_ROOT}/bin/route-auth-go.py:*)
---

# go

Conventions for Go services. Use what the repository already has; propose
a switch in an ADR (`bearing:adr`).

## Inputs

- Module: `go.mod` at the repository root; if several, the one named in
  the request.
- Public routes: `.bearing/public-routes.txt` in the repository (one
  `METHOD /path` per line); if absent, every route must carry auth.

## Steps

1. Handlers on the standard `net/http` mux with method patterns
   (`mux.HandleFunc("GET /orders/{id}", h)`).
2. Every route is wrapped in the repository's auth middleware
   (`requireAuth(h)`) unless it is listed as public.
3. Before finishing, run
   `python3 ${CLAUDE_PLUGIN_ROOT}/bin/route-auth-go.py <repo>` and fix
   every route it reports.
4. Table-driven tests; `httptest` for handlers.

## Output contract

```
Files: <paths>   go test: passed | failed   route-auth: N routes, M without auth
```

## Gotchas

- A route registered in a helper function is still a route; the check
  reads every `.go` file outside `vendor/`.
