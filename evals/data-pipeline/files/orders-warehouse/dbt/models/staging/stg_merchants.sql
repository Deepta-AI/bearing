-- Staging: the latest landed version of each merchant (the loader appends
-- a row per change since 3 August 2026, see docs/sources.md).
with ranked as (
    select
        merchants.id::bigint as merchant_id,
        merchants.name::text as merchant_name,
        lower(merchants.city)::text as city,
        merchants.onboarded_at::timestamptz as onboarded_at,
        row_number() over (
            partition by merchants.id
            order by merchants._loaded_at desc
        ) as version_rank
    from {{ source('raw', 'merchants') }} as merchants
)

select
    ranked.merchant_id,
    ranked.merchant_name,
    ranked.city,
    ranked.onboarded_at
from ranked
where ranked.version_rank = 1
