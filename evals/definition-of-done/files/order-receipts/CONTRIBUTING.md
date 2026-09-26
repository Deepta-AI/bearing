# Contributing

## Branches and commits

- Branch from `main`: `feature/ORD-123-short-name` or `bugfix/ORD-123-short-name`.
- Conventional Commits, ticket id in brackets at the end of the subject:
  `feat(orders): add status filter [ORD-123]`.

## Before you raise a merge request

- `make check` passes.
- Every endpoint is in `docs/api.md`, in the same MR that adds or changes it.
- Every environment variable the code reads is in `.env.example` with a
  comment.
- Every analytics event the code sends is in `docs/analytics/EVENT_SHEET.md`
  (name, trigger, properties, owner). The pipeline drops unknown events and
  rejects an event whose properties differ from the sheet.
