# payments-api SLOs

Agreed with payments product in the Q3 planning review. Window: rolling 30 days.

| SLO | Target | Indicator |
| --- | --- | --- |
| Availability | 99.95% | share of requests to /v1/payments that do not return 5xx (`http_requests_total`) |
| Latency | p99 under 500 ms | `http_request_duration_seconds` on /v1/payments |

Traffic on /v1/payments averages 1.2 million requests a day.

The availability target was raised from 99.9% to 99.95% when card checkout
moved onto this service. Burn-rate alerts live in `monitoring/alerts/slo.yaml`.
