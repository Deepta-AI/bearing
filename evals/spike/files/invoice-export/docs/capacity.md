# Capacity and targets

Last reviewed: 2026-03-18

| Item | Value |
| --- | --- |
| Largest export | 50,000 invoices (`MaxExportRows`) |
| Export response target | under 2 s at p99, measured at the pod |
| Pod size | 500m CPU, 256Mi memory (deploy/k8s.yaml) |
| Replicas | 3 |

The export builds the whole document in memory before writing it, so the
cap bounds both time and memory. Raise the cap only together with a new
measurement.
