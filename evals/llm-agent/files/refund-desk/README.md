# refund-desk

Support back office for the shop: tickets, orders, refunds and customer
email. Python 3.12+, standard library only (the platform security review
does not allow third-party packages in this repository). Storage is the
`Store` in `app/store.py`; production swaps in the Postgres-backed store from
the platform image, which has the same methods.

## Layout

- `app/store.py`: the data store and a synthetic seed used by tests and local runs
- `app/payments.py`: refunds through the payment gateway (money leaves the account)
- `app/notify.py`: customer email through the mail relay
- `app/llm.py`: `ModelClient`, the one interface for model calls, and the price table
- `app/llm_anthropic.py`: the production `ModelClient`; the SDK exists only in the
  platform image, so nothing in tests imports it
- `app/flags.py`: runtime flags read from `var/flags.json` (ops edit this file on
  the host; no deploy needed)

## Checks

    make check    # python3 -m unittest discover -s tests -t . -v

Tests must run offline with no API key: use the fakes in `tests/fakes.py`.
