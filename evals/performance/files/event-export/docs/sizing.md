# Sizing

Measured on production, 2026-09-01.

| Quantity | Value |
| --- | --- |
| Events per hour, busiest tenant, peak | 450,000 |
| Events per hour, median | 120,000 |
| Duplicate deliveries | about 0.5% of events |
| Rows in `accounts` | 3,000 (grows by about 20 a week) |
| Payload size | 150 to 400 bytes of JSON |

The worker pod has a 512 MiB memory limit (deploy/worker.yaml).
