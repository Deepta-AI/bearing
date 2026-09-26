# shopcore

Orders for the storefront. Partners (resellers who fulfil some orders)
poll `GET /orders?updated_since=` today.

- Domain events are written to an outbox in the same transaction as
  the order change (`internal/outbox`), and `cmd/worker` drains it.
- Partner records, including the name of the env var that holds each
  partner's shared secret, are in `internal/partners`.
- Schema changes: numbered SQL files in `migrations/`.

    make check   # go vet and go test
