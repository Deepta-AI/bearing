# ADR-0003: Ledger database on Cloud SQL for PostgreSQL

Status: Accepted

## Decision

- Cloud SQL for PostgreSQL 16, one instance per environment, one database
  `ledger`, one application user `ledger_app`.
- Sizing: dev and qa `db-custom-1-3840`, zonal. prod `db-custom-2-7680`,
  regional (high availability).
- Backups: daily automated backups in every environment; prod keeps 30 and
  has point-in-time recovery on. Storage location per ADR-0001.
- The prod instance must not be deletable by accident from any tool: not by
  a Terraform apply and not from the console, gcloud or the Cloud SQL API.
- The application user's password is generated, never typed, and kept in
  Secret Manager as `ledger-db-password`. Only the `ledger-api` service
  account may read it.
- The ledger-api pods reach the database over private IP (ADR-0002).
