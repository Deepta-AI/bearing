# ADR 0004: standard library only

Status: Accepted (2026-02-10)

## Context

The service is built into the back-office image by a pipeline with no
access to the public module proxy, and the security review of any
third-party module takes weeks.

## Decision

orders-api uses the Go standard library only. go.mod has no require
block. A change that needs a module outside the standard library goes
through a new ADR first.

## Consequences

JSON, routing and testing use encoding/json, net/http and testing.
