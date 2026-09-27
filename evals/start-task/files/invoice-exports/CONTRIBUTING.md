# Contributing

## Branches

- `main` holds released code only. `develop` is the integration branch.
- Every piece of work gets its own branch named
  `<type>/<TICKET>-<ShortName>`, where type is one of feature, bugfix,
  hotfix or chore, TICKET is the tracker id in capitals (PAY-123) and
  ShortName is two to four words in PascalCase, for example
  `feature/PAY-301-MonthQuery`.
- feature, bugfix and chore branches start from the latest `develop` on
  origin, never from a stale local copy. hotfix branches start from `main`.
- One ticket, one branch. Check nobody already has a branch for the ticket.

## Commits

Conventional commits with the ticket id at the end of the subject:
`feat(invoices): month query [PAY-301]`.

## Checks

`make check` must pass before a merge request is raised.
