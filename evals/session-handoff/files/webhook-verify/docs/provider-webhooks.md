# Provider webhooks

- `POST /webhooks/payments`, JSON body with `id` (the event id), `type` and `data`.
- `X-Timestamp`: Unix seconds when the provider sent the request.
- `X-Signature`: hex HMAC-SHA256 of `<X-Timestamp>.<raw body>` with the
  shared signing secret.
- Any non-2xx response is retried by the provider for up to 24 hours, so the
  same event id can arrive many times.
