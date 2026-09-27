# Contributing

- Branch from `develop`, name the branch `feature/<TICKET>-<slug>`, and open the
  merge request against `develop`. `main` only moves at a release.
- `make check` passes before every commit.
- Secrets come from the environment. Never commit a key, even a test one.
- A decision that changes how money is computed gets an ADR under `docs/adr/`
  and stays Proposed until finance operations signs it off.
