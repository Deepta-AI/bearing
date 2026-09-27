# invoicing

Issues invoices to business customers and records their payments.

- Go 1.25 service, Postgres 16 (one StatefulSet in the `invoicing` namespace).
- Money lives in the `billing` schema (invoices, payments); customers and the
  audit log live in `public`.
- Migrations: `migrations/`, applied in order at deploy.

## Operations

- Backups: `deploy/k8s/backup-cronjob.yaml`, see `docs/runbooks/backups.md`.
- Restore: `scripts/restore.sh`.
- Store facts, RPO and RTO: `docs/architecture/deployment.md`.

    make check    # vet, unit tests, shell syntax
