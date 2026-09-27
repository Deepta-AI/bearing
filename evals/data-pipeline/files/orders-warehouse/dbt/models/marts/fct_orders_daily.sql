{{
    config(
        materialized='incremental',
        unique_key=['order_date', 'merchant_id'],
        incremental_strategy='delete+insert',
        on_schema_change='fail'
    )
}}

-- Orders per day and merchant. Incremental by day: the DAG passes the
-- run's window in the start_date and end_date vars.
with orders as (
    select
        enriched.order_date,
        enriched.merchant_id,
        enriched.amount_cents
    from {{ ref('int_orders_by_merchant') }} as enriched
    where
        enriched.status != 'cancelled'
        and enriched.order_date >= cast('{{ var("start_date") }}' as date)
)

select
    orders.order_date,
    orders.merchant_id,
    count(*) as order_count,
    sum(orders.amount_cents) as gross_amount_cents
from orders
group by orders.order_date, orders.merchant_id
