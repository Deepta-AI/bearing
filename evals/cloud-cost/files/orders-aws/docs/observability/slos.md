# SLOs

| SLO | Target | Source |
| --- | --- | --- |
| orders-api availability | 99.9% of requests non-5xx, 30 day window | ALB HTTPCode_Target_5XX_Count over RequestCount |
| orders-api latency | 99% under 400 ms | ALB TargetResponseTime p99 |

## Monthly request volume (prod, ALB RequestCount sum)

| Month | Requests |
| --- | --- |
| 2026-06 | 176.2 M |
| 2026-07 | 179.9 M |
| 2026-08 | 186.4 M |
