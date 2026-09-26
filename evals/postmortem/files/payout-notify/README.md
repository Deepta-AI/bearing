# payout-notify

Sends partners the "payout sent" email after the nightly payout batch. The
payout batch itself (moving money) lives in the ledger service; this repository
only notifies.

- `notify/batch.py` reads the day's payouts and calls `notify/sender.py` for each.
- `notify/provider.py` is the client for the transactional email provider.
- Settings come from the environment (`notify/config.py`); production values
  are in `deploy/notify.env`, which the deploy job copies to the batch host.
- The job runs from `deploy/crontab` on the batch host.

## Working on it

    make check    # the tests

## Operations

- Postmortems: `docs/postmortems/`
- Tasks are tracked as `PAY-<n>`; releases are tags `vX.Y.Z`.
- Owners: see `CODEOWNERS`.
