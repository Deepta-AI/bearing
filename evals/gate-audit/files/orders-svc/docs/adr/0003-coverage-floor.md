# 0003. A coverage floor on internal packages

Status: Accepted (sprint 14 planning)

## Context

Two pricing regressions in sprint 12 shipped through code with no tests.

## Decision

`make check` fails when total statement coverage of `./internal/...` falls
below 70 percent. The floor is raised, never lowered, when coverage grows.

## Consequences

A change that deletes tests or adds untested code in `internal/` fails the
merge request until tests are added.
