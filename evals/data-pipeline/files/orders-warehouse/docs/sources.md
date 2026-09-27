# Raw sources

Everything in the `raw` schema is written by the loader. Nothing in this
repository writes to `raw`.

## Loader behaviour

Until 2 August 2026 the loader replaced each raw table with a daily
snapshot, one row per id. Since 3 August 2026 the new loader appends
instead: every insert or update in the source system lands as a new row
with the same id and a later `_loaded_at`. The current state of an id is
its row with the latest `_loaded_at`.

The loader keeps 60 days in `raw`: every night at 00:10 UTC it deletes
the rows of orders placed more than 60 days ago (by `placed_at`) and of
refunds requested more than 60 days ago (by `created_at`). `raw.merchants` is
kept in full.

## raw.orders

Landed by 00:30 UTC for the previous day.

| column | type | notes |
|---|---|---|
| id | bigint | order id |
| merchant_id | bigint | |
| placed_at | timestamptz | when the customer placed the order |
| status | text | `placed`, `shipped`, `delivered`, `cancelled` |
| amount_cents | bigint | order value in paise |
| _loaded_at | timestamptz | set by the loader |

Merchants can edit an order (amount, status) until 30 days after the day
it was placed; after that the order is locked.

## raw.merchants

Landed by 00:30 UTC. One row per merchant change, same append rule.

| column | type | notes |
|---|---|---|
| id | bigint | merchant id |
| name | text | |
| city | text | |
| onboarded_at | timestamptz | |
| _loaded_at | timestamptz | set by the loader |

## raw.refunds

Exported by the payment provider once a night at 02:30 UTC and landed by
03:00 UTC. Same append rule: a refund's status changes land as new rows.

| column | type | notes |
|---|---|---|
| id | text | refund id, for example `rf_8Hk2` |
| order_id | bigint | |
| merchant_id | bigint | |
| created_at | timestamptz | when the refund was requested |
| succeeded_at | timestamptz | null until the refund succeeds |
| status | text | `pending`, `succeeded`, `failed`, `reversed` |
| amount | numeric(12,2) | refund value in rupees, as the provider sends it |
| _loaded_at | timestamptz | set by the loader |

A refund usually succeeds one to three days after it is requested. The
provider can reverse a succeeded refund (a chargeback on the refund) up
to 45 days after it succeeded; the reversal lands as a new row with
status `reversed` and the original `succeeded_at`.
