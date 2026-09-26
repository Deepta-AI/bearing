# Dispatchly webhooks (copied from their developer docs, 2026-08)

Every webhook is a POST with a JSON body and this header:

    Dispatchly-Signature: t=1758612000,v1=5f1c2e...

`t` is the Unix time the request was signed. `v1` is the lowercase hex
HMAC-SHA256, keyed with your endpoint secret, of the string
`<t>.<raw request body>`. Compute it over the body exactly as received.

Rolling the secret: when you roll your endpoint secret in the dashboard,
Dispatchly signs every request with both the new and the old secret for
24 hours and sends both signatures, new first:

    Dispatchly-Signature: t=1758612000,v1=9a0b7d...,v1=5f1c2e...

Accept the request if any `v1` matches.

Body:

    {"id":"evt_8Kq2mX","type":"shipment.delivered","created":1758612000,
     "data":{"shipment_id":"shp_1042","status":"delivered","occurred_at":"2026-09-23T07:20:00Z"}}

`id` is unique per event and stays the same on every retry.

Delivery: a response with any 2xx status within 5 seconds counts as
received. Anything else (including a timeout) is retried with
exponential backoff for up to 72 hours. A 4xx other than 408 and 429
is treated as a permanent rejection and is not retried.

Resend: merchants can resend any event from the Dispatchly dashboard up
to 30 days after it was created. A resent event keeps its `id` and gets
a fresh `t`.

Ordering: events are not guaranteed to arrive in the order they
happened, and a retried event can arrive after a later one. Use
`data.occurred_at` to order them.

Timing: Dispatchly can send the first event for a shipment within a
second of your booking call returning, possibly before your own record
of the shipment is committed.
