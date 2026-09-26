# shop

Storefront for a single-brand shop: a React web app, a Go API, a
background worker and a search indexer.

## How it fits together

- `web` is the customer site; it calls the API under `/api`.
- `api` handles carts, orders, search and the staff admin. Carts are
  stored in Postgres (since 1.9.0).
- `worker` sends order confirmation emails.
- `indexer` keeps the Meilisearch product index up to date.
- Payments go through Razorpay.

## Running locally

    docker compose up

Production runs on Kubernetes; manifests are in `k8s/`. Architecture
diagrams are in `docs/architecture/`, decisions in `docs/adr/`.
