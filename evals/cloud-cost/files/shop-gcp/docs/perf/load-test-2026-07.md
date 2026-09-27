# Load test, 2026-07-28 (prod-sized pool, staging project)

Goal: confirm the new GKE pool holds the Diwali sale peak of 900 requests a
second.

| Measure | Result |
| --- | --- |
| Sustained rate | 900 req/s for 60 minutes |
| api pods | 12 (HPA minimum) |
| api CPU per pod, p95 | 0.7 cores |
| api memory per pod, p95 | 1.9 GiB |
| p99 latency | 310 ms |

The pool never needed to scale. CPU requests (3 cores a pod) were not
revisited after the move from VMs.
