# Deployment

## 1. Environments

| Environment | Project | Cluster | Database |
| --- | --- | --- | --- |
| prod | shop-prod | shop-prod (regional, asia-south1), pool of 6 x n2-standard-8 | pg-primary (Cloud SQL, regional HA, asia-south1) |
| staging | shop-staging | shop-staging (zonal), pool of 3 x n2-standard-8 | pg-staging |
| dev | shop-dev | shop-dev (zonal), pool of 2 x n2-standard-4 | pg-dev |

## 2. Components

- api: the storefront API (k8s/prod/api.yaml), behind the global external load balancer.
- reports: the merchant reporting service (k8s/prod/reports.yaml). It reads
  from pg-primary.
- pg-replica-dr: cross-region read replica of pg-primary in asia-south2,
  kept for disaster recovery only (docs/runbooks/dr.md).
- month-end-invoicer: a Compute Engine VM that builds the monthly invoices
  (docs/runbooks/month-end.md).

## 3. Network

One VPC per project. Private services access for Cloud SQL. Egress to the
internet through Cloud NAT.

## 10. Cost (placeholder)

To be filled from the billing export: monthly cost per component per
environment.
