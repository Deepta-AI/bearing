{{
    config(
        materialized='incremental',
        unique_key=['order_date', 'country'],
        incremental_strategy='delete+insert',
        on_schema_change='fail',
        pre_hook="{{ delete_window('order_date') }}"
    )
}}

-- Mart: orders per day and country. Incremental by partition: the window
-- [start_date, end_date) comes from vars, the DAG passes one day, a backfill
-- passes a range. The pre-hook deletes the whole window first, so a country
-- whose orders all vanished loses its row; delete+insert on the unique key
-- alone would keep it. Never --full-refresh in production.
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
