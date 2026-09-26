-- Intermediate: joins and business logic between staging and marts. Never
-- queried by a consumer directly.
select
    orders.order_id,
    orders.customer_id,
    orders.order_date,
    orders.status,
    orders.amount_cents,
    customers.country
from {{ ref('stg_orders') }} as orders
inner join {{ ref('stg_customers') }} as customers
    on orders.customer_id = customers.customer_id
