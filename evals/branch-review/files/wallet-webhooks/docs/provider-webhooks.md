# Provider webhooks: the contract we rely on

Summarised from the provider's documentation, September 2026.

## Signature

Every delivery carries

    X-Provider-Signature: t=<unix seconds>,v1=<hex>

where `v1` is HMAC-SHA256 with the endpoint's signing secret over the bytes
`<t>.` followed by the raw request body. Receivers must reject a delivery
whose signature does not match and must reject any delivery whose `t` is
more than 300 seconds from the receiver's clock, so a captured request
cannot be replayed. Each delivery attempt, retries included, is signed
afresh with the current `t`.

During a signing-secret rotation (up to 24 hours from when it is started in
the dashboard) the header carries one `v1` entry per active secret, in no
fixed order:

    X-Provider-Signature: t=<unix seconds>,v1=<hex>,v1=<hex>

A receiver accepts the delivery when any `v1` entry matches its secret.

## Delivery

- At least once. The same event (same `id`) can arrive more than once, and
  two deliveries of one event can arrive at the same time.
- A delivery counts as failed on any non-2xx response or no response within
  10 seconds. Failed deliveries are retried with backoff for up to 72 hours.
- New event types are added without notice. Receivers should acknowledge
  types they do not handle with a 2xx, or the provider keeps retrying them.

## Events we use

| Type | data |
|---|---|
| payment.succeeded | customer_id, amount (integer paise), email, phone |
| payment.refunded | customer_id, amount (integer paise), email, phone |
