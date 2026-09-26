# Sale-day load test, August 2026

Environment: staging (db.t4g.medium RDS, 2 Fargate tasks), 2026-08-28.
Traffic replayed at 5x the production median for 30 minutes.

| Metric | Value |
| --- | --- |
| GET /catalogue p95 latency | 320 ms |
| GET /search p95 latency | 190 ms |
| RDS CPU (peak) | 85% |
| New Postgres connections per second (peak) | 410 |

Production runs on db.r6g.large with 4 Fargate tasks.
