-- Staging: one model per raw table. Rename, cast, lower-case, nothing else.
-- Explicit columns; select * is a finding.
select
    raw_customers.id as customer_id,
    lower(raw_customers.email) as email,
    upper(raw_customers.country) as country,
    raw_customers.created_at
from {{ ref('raw_customers') }} as raw_customers
