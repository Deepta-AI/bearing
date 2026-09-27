select
    merchants.merchant_id,
    merchants.merchant_name,
    merchants.city,
    merchants.onboarded_at
from {{ ref('stg_merchants') }} as merchants
