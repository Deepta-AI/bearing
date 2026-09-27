# webhook-receiver

Receives payment events from the payment provider and hands them to the
orders service. See `docs/provider-webhooks.md` for what the provider sends.

    make check                                # vet and tests
    WEBHOOK_SIGNING_SECRET=... go run ./cmd/receiver

Branches: `feature/<TICKET>-<slug>` from `main`; merge requests target `main`.
