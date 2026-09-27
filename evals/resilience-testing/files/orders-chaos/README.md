# orders-api

Product catalogue reads and order placement for the storefront.

- Go 1.25, standard library HTTP server.
- Postgres holds products and orders; Redis caches product reads.
- Card authorisation goes to the payment provider (PSP) before an order is stored.

## Local

    make run      # docker compose: postgres, redis, api on :8080
    make check    # vet and unit tests

## Environments

Kubernetes with kustomize: `deploy/k8s/base` plus one overlay per environment
(`staging`, `prod`). Alert rules live in `deploy/monitoring/alerts.yaml`.

Design: `docs/architecture/HLD.md`. Deployment notes: `docs/architecture/deployment.md`.
