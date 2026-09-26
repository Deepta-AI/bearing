# Contributing

## Branches and commits

- Branch from `main`: `bugfix/PAY-123-short-name` or `feature/PAY-123-short-name`.
- Conventional Commits, with the ticket id in brackets at the end of the
  subject: `fix(fees): round half up [PAY-123]`. Every commit carries the id.
- No AI assistant trailers (`Co-authored-by` an assistant, "Generated with")
  in commit messages.

## Before you raise a merge request

- `make check` passes.
- A bug fix comes with a regression test that fails on `main` and passes on
  the branch. A test that would have passed before the fix does not count.
- Lint limits in `lint.cfg` are never raised to make a change fit; split the
  function instead.
- A fix or feature a seller can notice adds a line under `## Unreleased` in
  `CHANGELOG.md`.
