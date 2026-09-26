# payments-service

Refunds and the ledger for the shop. Talks to the card gateway over HTTP.

## Working on it

- Branch from `develop` as `feature/PAY-<n>-<slug>`; merge requests target
  `develop`. `main` only moves on a release.
- `make check` is the gate: it compiles everything and runs the tests, and
  ends with `check: passed`.
- Commit subjects are Conventional Commits with the ticket id, for example
  `feat(refunds): partial refunds [PAY-120]`.

## Configuration

Read from the environment by `src/payments/config.py`; `.env.example` lists
every variable with its default.

| Variable | Default | Meaning |
| --- | --- | --- |
| `GATEWAY_URL` | `http://localhost:9000` | Card gateway base URL |
| `GATEWAY_TIMEOUT_S` | `10` | Timeout for one gateway call, seconds |
| `REFUND_MAX_ATTEMPTS` | `3` | Gateway calls per refund before giving up |
| `REFUND_BACKOFF_MS` | `200` | First retry delay; doubles on each retry |
