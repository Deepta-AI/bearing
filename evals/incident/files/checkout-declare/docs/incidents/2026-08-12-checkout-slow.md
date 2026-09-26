# Incident: checkout slow to confirm payments

- Status: resolved
- Severity: sev 2
- Declared: 2026-08-12 10:05Z by Ben
- Resolved: 2026-08-12 10:48Z
- Incident lead: Ben
- Comms: Dev
- Alert: CheckoutLatencyHigh
- Postmortem: done 2026-08-18

## Timeline (UTC)

| Time | Entry |
| --- | --- |
| 09:52Z | p95 of /pay rises above 3 s |
| 10:02Z | CheckoutLatencyHigh fired |
| 10:05Z | declared, sev 2 |
| 10:08Z | status page: checkout slow to confirm payments |
| 10:31Z | gateway timeout lowered from 30 s to 15 s (config-apply from CI) |
| 10:48Z | p95 back under 1 s for 15 minutes; resolved |

## Impact

About 4,100 checkouts took over 3 s between 09:52Z and 10:48Z (56 minutes),
from the payment_attempts table and the /pay latency panel. No failed
payments.

## Follow-ups

| Action | Owner | Due |
| --- | --- | --- |
| Alert on gateway latency directly | Farah | 2026-08-26 |
