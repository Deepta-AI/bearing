# Changelog

## 1.8.0 (2026-09-18)

- Migration 0007 drops `events.legacy_payload`. The worker reads only
  `payload` from this release on.
- Releases 1.7.x and earlier still read `legacy_payload` when `payload` is
  null and fail on every event once 0007 has run.

## 1.7.2 (2026-08-30)

- Orders API timeout lowered from 60 s to 30 s.

## 1.6.0 (2026-07-14)

- Signature check accepts a second secret, `WEBHOOK_SIGNING_SECRET_PREVIOUS`,
  so a provider secret rotation does not reject events while both are live.
- `scripts/replay_dead.py` filters by `--error` and supports `--dry-run`.
