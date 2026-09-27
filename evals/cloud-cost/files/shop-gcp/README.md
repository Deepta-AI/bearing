# shop

Storefront API and reporting for the shop, on Google Cloud.

- Projects: shop-prod, shop-staging, shop-dev. Primary region asia-south1
  (Mumbai); the disaster recovery replica is in asia-south2 (Delhi).
- We moved from VMs to GKE on 2026-07-18; July was the first month on the
  new node pools.
- Staging is used by the QA team on weekdays, 10:00 to 19:00 IST. Dev is
  used during office hours.
- The billing account carries a startup program credit of INR 7,20,000
  granted in October 2025; it is applied against Compute Engine and expires
  on 2026-09-30.

## Billing

Finance exports the billing account to BigQuery and drops a flattened CSV
per invoice month into billing/ (`cost` is before credits; `credits_total`
and `credit_details` list the credits applied to the row).

## Layout

- terraform/: projects, network, Cloud SQL, the invoicer VM
- k8s/: manifests per environment
- docs/architecture/deployment.md: the deployment view
