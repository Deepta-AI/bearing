# 2. One package for data access

Date: 2026-03-04

## Status

Accepted

## Context

Handlers were opening database connections themselves, so every handler
carried its own retry and timeout rules.

## Decision

All data access lives in `internal/store/`. Handlers receive a `*store.Store`
and never import the driver.

## Consequences

One place to change timeouts. Tests fake the store, not the database.
