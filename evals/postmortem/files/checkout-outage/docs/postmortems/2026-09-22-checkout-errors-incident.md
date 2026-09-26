# Incident: Checkout errors (sev 2, resolved)

- Declared: 2026-09-22 08:36Z, sev 2
- Roles: incident lead and scribe: payments on-call; comms: support lead
- Status: resolved 09:20Z
- Last deploy: none that day (checked the deploy channel)
- runbook: docs/runbooks/CheckoutErrorRateHigh.md not updated yet
- Data: `incident-data/5xx-by-minute.csv` (API dashboard, 5xx panel export)
  and `incident-data/chat-export.txt` (incident channel)

## Status

Resolved by rolling back to v2.2.4.

## Timeline (UTC)

- 14:04Z CheckoutErrorRateHigh fired
- 08:36Z declared, sev 2
- 08:42Z restarted all checkout pods (runbook step 1)
- ~08:45Z errors back
- 08:56Z PoolTimeout errors seen in the logs
- 09:08Z decision: roll back to v2.2.4
- 09:14Z rollback done, error rate normal
- 09:20Z resolved

## Impact

About 5,000 failed checkouts (rough, read off the error panel by eye).

## Root cause hypothesis

Database primary was slow. Dev One also merged a pool change last week
without anyone reviewing it; check.

## Follow-ups (draft)

- Restore pool size to 20
- Add more monitoring
- Look into the DB CPU
