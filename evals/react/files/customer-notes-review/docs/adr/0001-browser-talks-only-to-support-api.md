# ADR-0001: The browser talks only to the support API

Status: Accepted (2026-03-04)

## Context

The console runs in the browser of every support agent. Anything the bundle
contains, and any request it makes, is visible to whoever opens the developer
tools.

## Decision

The console calls only the support API at `VITE_API_BASE_URL`. Calls to
third-party services (payments, email, the text summarisation provider) are made
by the support API, which holds their credentials. No third-party credential is
ever put in a `VITE_` variable.

## Consequences

A new third-party capability needs a support API endpoint first.
