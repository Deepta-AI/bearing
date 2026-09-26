# 0002. Production deploys are manual

Status: Accepted (2026-04-14)

## Context

The ledger feeds month-end close. An unreviewed deploy during close has cost
us a reconciliation day once already.

## Decision

- There is one environment, production. There is no staging deploy.
- A production deploy is started by a person, from a pipeline on `trunk`,
  never automatically on merge or push.
- `DEPLOY_TOKEN` lives only in GitLab as a masked, protected CI variable.
  It is never written in the repository.

## Consequences

Whoever sets up the pipeline makes the deploy job manual and limits it to
`trunk`.
