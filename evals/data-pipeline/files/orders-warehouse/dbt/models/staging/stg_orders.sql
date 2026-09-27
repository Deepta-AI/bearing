-- Staging: rename and cast raw.orders.
select
    orders.id::bigint as order_id,
    orders.merchant_id::bigint as merchant_id,
    orders.placed_at::timestamptz as placed_at,
    (orders.placed_at at time zone 'UTC')::date as order_date,
    lower(orders.status)::text as status,
    orders.amount_cents::bigint as amount_cents,
    orders._loaded_at::timestamptz as loaded_at
from {{ source('raw', 'orders') }} as orders
