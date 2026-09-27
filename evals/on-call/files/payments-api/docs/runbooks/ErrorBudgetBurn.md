# PaymentsErrorBudgetFastBurn and PaymentsErrorBudgetSlowBurn

## What it means
payments-api is returning 5xx faster than the availability SLO in
docs/observability/slos.md allows. Fast burn: the monthly budget would be
gone in about two days. Slow burn: in about five.

## Check
1. Which status codes? `sum by (code) (rate(http_requests_total{job="payments-api",code=~"5.."}[5m]))`
2. Is the card provider failing? `provider_requests_total{result="error"}`
   (see PaymentsProviderErrors).
3. Any deploy in the last hour? `kubectl -n payments rollout history deployment/payments-api`

## Act
- Bad deploy: `kubectl -n payments rollout undo deployment/payments-api`.
- Provider outage: declare Sev 1 and post in #payments-alerts.

## Escalate
Fast burn not improving in 15 minutes: page the secondary.
