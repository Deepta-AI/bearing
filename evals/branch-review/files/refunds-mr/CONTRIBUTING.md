# Contributing

## Commits

Conventional Commits with the ticket id at the end of the subject:

    feat(refunds): allow partial refunds PAY-212

One logical change per commit.

## Merge requests

- Every new or changed endpoint has tests for the role check and for a
  principal of another merchant (the response is 404, never the resource).
- Amounts follow ADR-0002.
- `docs/api.md` is updated in the same MR as the endpoint.
- `make check` passes.
