{{
    config(
        materialized='incremental',
        unique_key=['order_date', 'country'],
        incremental_strategy='delete+insert',
        on_schema_change='fail'
    )
}}

-- Mart: orders per day and country. Incremental by partition: the window
-- [start_date, end_date) comes from vars, the DAG passes one day, a backfill
-- passes a range, and delete+insert on the unique key makes any re-run of
-- the same window idempotent. Never --full-refresh in production.
with orders as (
    select
        enriched.order_date,
        enriched.country,
        enriched.status,
        enriched.amount_cents
    from {{ ref('int_orders_enriched') }} as enriched
    where
        enriched.order_date >= cast('{{ var("start_date") }}' as date)
        and enriched.order_date < cast('{{ var("end_date") }}' as date)
)

select
    orders.order_date,
    orders.country,
    count(*) as order_count,
    sum(case when orders.status = 'completed' then orders.amount_cents else 0 end)
        as revenue_cents,
    sum(case when orders.status = 'refunded' then 1 else 0 end) as refunded_count
from orders
group by orders.order_date, orders.country
