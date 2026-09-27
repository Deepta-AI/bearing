# orders

Order and invoicing API for the shop, on AWS ap-south-1 (account 111122223333).

- Three EKS clusters: orders-prod, orders-qa, orders-dev (terraform/eks.tf).
- Postgres on RDS per environment, Redis sessions in prod only.
- The nightly reporting batch runs on its own EC2 instance (docs/runbooks/reporting.md).
- Logs ship from the pods to CloudWatch Logs through the Fluent Bit daemonset.

## Billing

Finance drops the monthly Cost and Usage Report extract into billing/ as
`aws-cur-<YYYY-MM>.csv` (unblended cost, one row per resource and usage type).
The monthly cost review lives in docs/cost/, one file per month.

## Layout

- terraform/: the AWS resources
- k8s/: the manifests per environment
- docs/adr/: decisions
- docs/observability/slos.md: SLOs and monthly request volumes
