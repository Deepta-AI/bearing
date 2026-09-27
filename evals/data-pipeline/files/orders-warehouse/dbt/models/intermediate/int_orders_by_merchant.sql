-- Orders with their merchant's city, for the order marts.
select
    orders.order_id,
    orders.order_date,
    orders.merchant_id,
    merchants.city,
    orders.status,
    orders.amount_cents
from {{ ref('stg_orders') }} as orders
inner join {{ ref('stg_merchants') }} as merchants
    on orders.merchant_id = merchants.merchant_id
