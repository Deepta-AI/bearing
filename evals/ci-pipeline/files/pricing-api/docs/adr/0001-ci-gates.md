# 0001. What CI enforces

Status: Accepted (2026-05-06)

## Decision

- `make lint` (go vet, gofmt) and `make test` are merge gates: a pull
  request cannot merge while either fails. The `ci` workflow's checks are
  required in the branch protection of `main`.
- CI calls make targets only, so a contributor can reproduce any failure
  locally.

## Amendment (2026-07-21)

The lint job is advisory (`continue-on-error`) while the go vet findings
from the 1.25 upgrade are fixed. Make it blocking again as soon as
`make lint` is clean on `main`.
