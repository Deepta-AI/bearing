# Cost review: 2026-07

Source: billing/aws-cur-2026-07.csv (not kept in the repo)   Lines: 49   Basis: unblended
Total: USD 13,618.45   Previous month: USD 13,410.80 (+1.5%)
Reviewed: 2026-08-05   Owner: platform rotation   Next review: first working week of September

## Top lines

| # | Line | Service | Env | Amount | % of total |
| --- | --- | --- | --- | --- | --- |
| 1 | orders-db-prod (Multi-AZ db.r6g.2xlarge) | RDS | prod | 1,523.71 | 11.2% |
| 2 | NAT gateway data processing (both AZs) | VPC | prod | 1,120.00 | 8.2% |
| 3 | DataTransfer-Out to internet | Data transfer | prod | 684.10 | 5.0% |
| 4 | EBS snapshots (untagged) | EC2 | none | 640.00 | 4.7% |
| 5 | /orders/app log ingestion | CloudWatch | prod | 610.00 | 4.5% |
| 6 | reporting instance i-0f9a3reporting1 (untagged) | EC2 | none | 571.39 | 4.2% |
| 7-12 | prod EKS nodes, 6 x m6i.4xlarge | EC2 | prod | 571.39 each | 4.2% each |

## Unit economics

Prod total USD 9,407.47 over 179.9 M requests (docs/observability/slos.md) = USD 0.052 per 1000 requests.

## Decisions

| Proposal | Decision | Owner | Ticket |
| --- | --- | --- | --- |
| Delete the search-poc OpenSearch domain (POC ended in June, no traffic since) | Accepted, delete by 2026-08-10 | platform rotation | OPS-431 |
| Delete unattached volumes vol-0d1e44a9 and vol-0d2f81c3 | Deferred to 2026-09-15: the data team is checking whether vol-0d2f81c3 holds the 2024 export | data team | OPS-433 |
| Compute Savings Plan for the prod node baseline | Deferred to the October review: prod has been stable only since May, and the node group is due for rightsizing first | platform rotation | none |
| Switch dev off overnight and at weekends | Accepted from 2026-09-01 | platform rotation | OPS-436 |
| Switch qa off overnight | Declined: ADR-0003 | | |
