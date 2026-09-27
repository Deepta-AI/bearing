# ADR 0002: Feature flags

Status: Accepted (2026-03-02)

## Context

Unfinished work was being kept on long-lived branches, and merges were
painful. We want to merge dark instead.

## Decision

- Every flag is a typed constant in `internal/flags`. Values come from
  `FLAG_<NAME>` environment variables, read once at startup. Nothing
  else in the code reads a `FLAG_` variable.
- Every flag defaults off. A missing variable means off.
- Every flag has a row in docs/operations/flags.md with an owner (the
  on-call rotation of the owning team, never a person), the removal
  ticket and a removal target date no more than 90 days after the flag
  is added.
- Whoever adds a flag checks the register for rows past their target
  date and raises them in the pull request.
- Each flag is tested in both states.

## Consequences

Flags are cheap to add, so the register is how we stop them piling up.
