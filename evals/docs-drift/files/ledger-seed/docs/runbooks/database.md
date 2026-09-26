# Runbook: local and staging database

Owner: platform rotation. Last reviewed 2026-08-20.

## Seed demo data

1. `make seed` loads 100 demo rows into the file named by `LEDGER_DB`.
2. For a different count run `python3 scripts/seed.py --rows 500`.
3. Check: the command prints `seeded 100 rows into ledger.jsonl`.

## Reset

`make db-reset` deletes the file; seed again afterwards.

## Rollback

Seeding only inserts; a reset and a fresh seed is the rollback.
