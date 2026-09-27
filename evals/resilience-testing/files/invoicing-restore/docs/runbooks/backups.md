# Runbook: Postgres backups

## What runs

The `pg-backup` CronJob dumps the database every night and copies the dump to
`$BACKUP_BUCKET`. After each upload the job deletes all but the newest 7
dumps.

## Checking backups

    aws s3 ls "$BACKUP_BUCKET/" | tail -n 7

Each dump should be about 6 GB. A dump much smaller than the one before is a
reason to page the owner.

## Log

- 2026-06-02: Postgres upgraded from 15 to 16 (StatefulSet image
  postgres:16, dump and reload). No other changes.
- 2026-03-14: quarterly backup check. Listed the bucket, 7 dumps present,
  sizes 5.8 to 6.1 GB, newest from 02:00 that night. Looks healthy.
- 2026-02-20: storage migration to the new volume class. WAL archiving turned
  off during the copy; to be re-enabled afterwards.
