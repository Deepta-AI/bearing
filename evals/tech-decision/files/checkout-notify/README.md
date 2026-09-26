# checkout

Go service behind the storefront's checkout. It takes the order, charges
the card through the payment service and sends the order confirmation by
SMS (MSG91) and email (Postmark).

Runs on Cloud Run in asia-south1 with Cloud SQL for PostgreSQL 16 (see
`docs/adr/`). Decisions are recorded with adr-tools in `docs/adr/`.

    go run ./cmd/api
