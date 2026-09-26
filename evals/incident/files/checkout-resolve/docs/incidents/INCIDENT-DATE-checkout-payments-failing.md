# Incident: checkout card payments failing

- Status: mitigating
- Severity: sev 2
- Declared: INCIDENT-DATE 08:47Z by Asha
- Resolved:
- Incident lead: Asha
- Comms: Chitra
- Scribe: Asha
- Alert: PaymentsDeclineRateHigh (docs/runbooks/PaymentsDeclineRateHigh.md)
- Service: checkout-api
- Postmortem:

## Current picture

Card payments at checkout have been failing since about 08:29Z. v2.7.0
rolled back out at 09:14Z; watching the decline rate.

## Timeline (UTC)

| Time | Entry |
| --- | --- |
| 08:24Z | v2.7.1 rolled out to production (CI) |
| ~08:29Z | decline rate starts rising on the payments dashboard (read off the graph at 08:58Z) |
| 08:41Z | PaymentsDeclineRateHigh fired (warning), decline rate 11 percent |
| 08:47Z | declared, sev 2 |
| 08:50Z | status page: investigating failed card payments at checkout |
| 08:52Z | runbook Diagnosis 1: gateway status page all green |
| 08:55Z | "Declines by code": almost all `auth_failed`, including cards that never go through 3DS; decline rate 96 percent, effectively every card payment failing |
| 09:02Z | runbook Remediation 2: CHECKOUT_3DS_V2=false applied with config-apply from CI; decline rate unchanged |
| 09:06Z | v2.7.1 reads PAYMENTS_3DS_V2_ENABLED, not CHECKOUT_3DS_V2, so the 09:02Z change did nothing; lead decides to roll back instead of retrying the flag |
| 09:08Z | runbook Remediation 1: `make rollback VERSION=v2.7.0` failed with "No rule to make target 'rollback'"; CI ran `make deploy TAG=v2.7.0` instead |
| 09:14Z | v2.7.0 rollout complete |
| 09:16Z | support: two customers report being charged twice after retrying a failed payment |

## Comms log

| Time | Audience | Message |
| --- | --- | --- |
| 08:50Z | status page | investigating: some card payments at checkout are failing |
| 08:51Z | #shop-incidents | sev 2 declared, lead Asha, comms Chitra |
