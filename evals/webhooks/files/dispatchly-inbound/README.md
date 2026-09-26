# parcelpost

Tracks customer shipments. The courier aggregator Dispatchly calls
`POST /webhooks/dispatchly` when a shipment moves; on delivery we email
the customer.

- Webhook secret: env `DISPATCHLY_WEBHOOK_SECRET`.
- Background work goes through `internal/jobs` (an in-process queue
  today; Postgres-backed queue planned).
- Schema changes: numbered SQL files in `migrations/`.

    make check   # go vet and go test
