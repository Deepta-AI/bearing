# HighLatency: payments-api p99 above 500 ms

## What it means
The 99th percentile of `http_request_duration_seconds` for payments-api has
been above 500 ms for 10 minutes. Customers see slow checkout; the latency
SLO in docs/observability/slos.md is at risk.

## Check
1. Is it every pod or one? `kubectl -n payments top pods -l app=payments-api`
2. Is the database slow? Look at `pg_stat_activity_count` against
   `pg_settings_max_connections`; if near the limit, follow
   PostgresConnectionsExhausted.md.
3. Did a deploy just happen? `kubectl -n payments rollout history deployment/payments-api`

## Act
- A bad deploy: `kubectl -n payments rollout undo deployment/payments-api`.
- One hot pod: delete it and let the deployment replace it.
- Otherwise scale out: `kubectl -n payments scale deployment/payments-api --replicas=6`.

## Escalate
If latency is not falling 20 minutes after acting, escalate to the
secondary and open a Sev 2.
