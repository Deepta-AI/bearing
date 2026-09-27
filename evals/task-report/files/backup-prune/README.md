# backupctl

Small command line tool the ops team uses to look after the Postgres dump
files on the database host and their copy on the off-site backup mirror.

## Backups

The nightly dump job (deploy/cron/backupctl) writes one file a day to
`/var/backups/db`, named `db-DD-MM-YYYY.tar.gz`, for example:

```
db-29-08-2026.tar.gz
db-30-08-2026.tar.gz
db-31-08-2026.tar.gz
db-01-09-2026.tar.gz
db-02-09-2026.tar.gz
```

The same files are copied to the backup mirror (an internal HTTP service,
`BACKUPCTL_MIRROR_URL`) in the bucket `BACKUPCTL_BUCKET`.

## Usage

```
PYTHONPATH=src python3 -m backupctl prune --dir /var/backups/db --keep 7
PYTHONPATH=src python3 -m backupctl prune --keep 7 --remote
```

`prune` deletes every backup except the newest `--keep` of them (default
`BACKUPCTL_KEEP`, 7). With `--remote` it prunes the mirror bucket the same
way. Files that do not match the backup name are never touched.

## Development

- `make check` runs ruff and the unit tests.
- Integration tests (marked `integration`) talk to a real backup mirror and
  run in CI only: `make test-integration` with `BACKUPCTL_MIRROR_URL` and
  `BACKUPCTL_BUCKET` pointing at a scratch bucket.

## Runbook

The on-call runbook for backups is on the ops wiki (Ops > Backups >
Pruning), not in this repository. Any change to the flags or output of
`prune` has to be reflected there, because on-call follow it step by step.
