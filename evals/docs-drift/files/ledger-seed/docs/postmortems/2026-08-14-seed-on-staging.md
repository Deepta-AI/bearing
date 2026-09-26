# Postmortem: demo rows seeded into staging (2026-08-14)

## Summary

`scripts/seed.py` ran against staging because `LEDGER_DB` pointed at the
staging file on a shared runner. 100 demo rows sat in staging for 40 minutes.

## Actions

- Seed refuses a path outside the working directory (done).
- The runbook names the variable to check before seeding (done).
