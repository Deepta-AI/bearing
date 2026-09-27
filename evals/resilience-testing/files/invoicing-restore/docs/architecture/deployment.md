# invoicing: deployment

## Stores

| Store | Where | Backups | Retention | RPO | RTO | Last restore test |
| --- | --- | --- | --- | --- | --- | --- |
| Postgres `invoicing` | StatefulSet `pg`, namespace `invoicing`, 100 Gi volume | nightly `pg_dump` to S3 plus continuous WAL archiving | 7 daily dumps | 1 h | 30 min | 2026-03-14 |

Database size: about 38 GB on disk; the nightly dump is about 6 GB and takes
roughly 35 minutes.

## Disaster recovery

Single region (eu-west). Losing the volume means restoring the latest dump
into a new StatefulSet and repointing the service with `scripts/restore.sh`.
