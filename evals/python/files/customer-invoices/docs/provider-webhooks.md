# Payment provider webhooks

The provider posts every event for our account to ONE URL, configured in
its dashboard: `https://api.<host>/webhooks/payments`. There is one URL
per account; event types are told apart by the `type` field.

- Delivery is at least once. A timeout or any non-2xx answer is retried
  for up to 3 days, and the same event (same `id`) can also arrive twice
  after a 2xx. Apply each event id once.
- `X-Signature: sha256=<hex>` is the HMAC-SHA256 of the raw request body
  with the webhook secret. Verify the bytes as received; the provider's
  JSON has its own key order and spacing.
- Answer within 10 seconds.

Payload (fields we use):

    {
      "id": "evt_01J...",
      "type": "payment.succeeded" | "refund.succeeded" | "...",
      "created": "2026-09-01T10:00:00Z",
      "data": {
        "invoice_id": "inv_...",
        "amount_minor": 125000,
        "currency": "INR",
        "customer_email": "person@example.com"
      }
    }

`customer_email` is personal data: never log it.
