-- Mart: one row per customer with their first order. Rebuilt in full; it is
-- small and has no partition key.
with first_orders as (
    select
        orders.customer_id,
        min(orders.order_date) as first_order_date,
        count(*) as order_count
    from {{ ref('stg_orders') }} as orders
    group by orders.customer_id
)

select
    customers.customer_id,
    customers.email,
    customers.country,
    customers.created_at,
    first_orders.first_order_date,
    coalesce(first_orders.order_count, 0) as order_count
from {{ ref('stg_customers') }} as customers
left join first_orders
    on customers.customer_id = first_orders.customer_id
