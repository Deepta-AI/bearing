# refund-service

Computes refund amounts for the storefront's order lines and records why each
refund was made.

    make check    # the unit tests; run before every commit

Configuration comes from the environment: `PAYGATE_API_KEY` (the payment
gateway key, never committed) and `REFUND_CURRENCY` (default `INR`).
