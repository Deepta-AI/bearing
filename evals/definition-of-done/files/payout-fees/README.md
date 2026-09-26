# payouts

Settles marketplace orders into seller payouts. Every amount is an integer
number of paise; nothing in this service uses floats for money.

- `src/payouts/fees.py`: the platform fee on an order line.
- `src/payouts/settlement.py`: turns a batch of order lines into one payout
  per seller.
- `scripts/lint.py`: the house lint (no `print`, function length limit from
  `lint.cfg`).

## Checks

    make check    # lint, then the tests

There is no server here; settlement runs as a library inside the nightly
payout job, which lives in another repository.
