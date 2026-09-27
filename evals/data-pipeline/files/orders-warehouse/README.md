# orders-warehouse

The marketplace's analytics pipeline: raw tables landed by the loader in
the `raw` schema, dbt models in `dbt/`, one Airflow 3 DAG in `dags/`.
Finance and the merchant success team read the `marts` schema.

## Layout

- `dbt/models/staging`: one `stg_` model per raw table, rename and cast only.
- `dbt/models/intermediate`: joins shared by more than one mart.
- `dbt/models/marts`: `dim_` and `fct_` tables that people read.
- `dags/daily_orders.py`: the nightly run, one day per run.
- `docs/sources.md`: what the loader lands, when, and in what shape.
- `docs/adr/`: decisions.

## Commands

    make check                                   # pytest over the DAG and the dbt layout (offline)
    make dbt-build                               # dbt build against DBT_* (needs a warehouse)
    make backfill start=2026-01-01 end=2026-02-01

## Metric definitions (agreed with finance)

- An order counts on its `order_date` (the date it was placed, UTC) unless
  its current status is `cancelled`.
- Gross amount is the order's current `amount_cents`.
- A refund counts on the date it succeeded (`succeeded_at`, UTC), not the
  date it was requested. Only refunds whose current status is `succeeded`
  count.
- All amounts are INR and are reported in paise (minor units, integers).
