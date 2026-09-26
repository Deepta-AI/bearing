# ledger-sync

Pulls bank statements from partner banks, matches them against invoices
and posts the results to the accounting ledger.

## Local development

`docker compose up` starts the API with Postgres and Redis.
`make migrate-up` applies the migrations in `migrations/`.

## Deployment

Deployed to Kubernetes with the Helm chart in `helm/ledger`. Prod runs
3 replicas of the API. Merges to main go to QA automatically; prod is a
button in GitLab.
