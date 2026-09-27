# billing-api

Invoicing and payment-status API for Riverton's customer portal. FastAPI on
Postgres, deployed to Riverton's Kubernetes cluster.

Current release: v2.1.0

## Local

    cp .env.example .env
    make run

## Checks

    make check

## Deploy

CI builds the image on every push to main and on tags, and deploys tags to
production. By hand: `make deploy`.

Rollback: see docs/runbooks/rollback.md.

Built and maintained by Brightline Software Private Limited.
