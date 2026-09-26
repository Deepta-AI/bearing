---
paths:
  - "**/*.tf"
  - "**/*.tfvars"
  - "k8s/**"
  - "**/*.yaml"
---

# Infra rules (loaded when Terraform or Kubernetes files are touched)

- The agent never runs `terraform apply`, `terraform destroy` or `kubectl
  apply`. Plan, post the plan, stop. A person applies from the pipeline.
- State is remote and locked; no local state, no `-refresh=false`.
  Address changes are `moved`, `import` and `removed` blocks; `state rm`
  or `state mv` only as a fallback with a task id.
- `terraform test` files are plan mode with mock providers; an apply-mode
  test is an apply.
- Every resource lives in a module or carries a comment saying why not.
- Every variable: type, description, validation. Every value another repo
  reads: an output.
- IAM: named principals, named roles, no wildcard actions, no `roles/owner`
  or `roles/editor`. No `0.0.0.0/0` ingress except a documented public LB.
- Secrets from a secret manager only; no value in a tfvars file or manifest;
  `terraform.tfvars` never in git.
- Providers pinned with `~>`; images pinned by tag in dev and qa, by digest
  in prod; never `latest`.
- Every workload: requests and limits, liveness and readiness probes, a PDB
  above one replica.
- Every alert rule: a `runbook_url` annotation pointing at `docs/runbooks/`.
- Stateful resources: `prevent_destroy`, backups, encryption at rest.
- A plan that destroys or replaces is the first line of the MR description.
