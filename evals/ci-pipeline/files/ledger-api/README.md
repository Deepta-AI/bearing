# ledger-api

Double-entry ledger for the finance team: accounts, postings and balances
over a small JSON HTTP API. Hosted on our GitLab at
`code.example.internal/finance/ledger-api`; merge requests target `trunk`.

## Requirements

- Python 3.11 or newer
- Postgres 16 for the integration tests and for running the service

## Working on it

```
make install            # pip install -e '.[dev]'
make test               # unit tests, no database needed
make test-integration   # needs DATABASE_URL pointing at an empty Postgres database
make migrate            # applies migrations/*.sql to DATABASE_URL
make run                # serves on :8080
```

Lint with ruff; the rules are in `pyproject.toml`.

## Deploys

See docs/adr/0002-deploys.md. `make deploy` is what the release job runs.
