# PostgresConnectionsExhausted

## What it means
The payments database is above 90% of max_connections. New checkouts will
start failing with connection errors soon.

## Check
1. Connections by state: `sum by (state) (pg_stat_activity_count{job="postgres"})`
2. Many idle in transaction? A stuck release is holding connections.

## Act
- Restart the payments-api pods one at a time:
  `kubectl -n payments rollout restart deployment/payments-api`.
- Do not raise max_connections without the SRE team.

## Escalate
Still above 90% after the restart: page the secondary and the SRE team.
