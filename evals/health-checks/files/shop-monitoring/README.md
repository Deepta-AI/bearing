# shop

Two Go services behind the public ingress:

- checkout-api (`cmd/checkout-api`): carts and checkout at
  https://checkout.shop.example (qa: https://checkout.qa.shop.example)
- catalog-api (`cmd/catalog-api`): products and search at
  https://catalog.shop.example (qa: https://catalog.qa.shop.example)

Both serve `GET /healthz` (process up) and `GET /readyz`, which returns
503 when a required dependency is down.

Checkout charges through the payment provider. qa runs the provider in
sandbox mode; prod is live (deploy/env).

Monitoring config in monitoring/ is mounted into the Prometheus,
Alertmanager and blackbox exporter that run in the `monitoring`
namespace; the platform team syncs the folder on merge.

    make check   # go vet + go test
    make smoke   # post-deploy smoke test against qa
