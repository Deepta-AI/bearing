# shop

Storefront for a single-brand shop: a React web app, a Go API and a
background worker.

## How it fits together

- `web` is the customer site; it calls the API under `/api`.
- `api` handles carts, orders and the staff admin. Carts are cached in
  Redis. After an order is placed the API calls the worker over HTTP to
  send the confirmation email.
- `worker` sends emails.
- Payments go through Razorpay.

## Running locally

    docker compose up

Production runs on Kubernetes; manifests are in `k8s/`.
