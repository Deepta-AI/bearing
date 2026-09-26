-- Staging: one model per raw table. Rename, cast, lower-case, nothing else.
select
    raw_orders.id as order_id,
    raw_orders.customer_id,
    raw_orders.order_date,
    lower(raw_orders.status) as status,
    raw_orders.amount_cents
from {{ ref('raw_orders') }} as raw_orders
