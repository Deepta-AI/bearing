# Infrastructure guidelines

## Repository shape

- `modules/<name>/` holds one concern each (network, service-account,
  database, cluster). A module has `main.tf`, `variables.tf`, `outputs.tf`
  and `versions.tf`, and nothing it did not need to declare.
- `envs/<env>/` is a root module that wires modules together. It owns the
  backend, the provider and the values; it declares no resources of its
  own except with a comment saying why (see Stateful resources).
- `k8s/base/` describes the workload once; `k8s/overlays/<env>/` changes
  only what differs per environment: namespace, replicas, image, limits.
- `monitoring/alerts/` and `monitoring/dashboards/` ship with the service
  they watch, in this repo, so the MR that changes a threshold is reviewed
  next to the code that caused it.
- `scripts/` holds bash that CI and engineers run the same way. Every
  script passes `shellcheck -x`.

## Environments

- Three environments, `dev`, `qa`, `prod`, one directory each. Not
  workspaces: workspaces share a backend block and a variable set, so the
  only thing separating a dev plan from a prod apply is the current
  workspace name, and a plan file does not record it. Directories make the
  environment part of the path, the state prefix, the CI job name and the
  diff.
- The three roots stay structurally identical. A difference between them is
  a value in `terraform.tfvars` or `variables.tf` defaults, not a different
  set of modules.
- CIDRs never overlap across environments (dev `10.10`, qa `10.20`, prod
  `10.30` by default), so peering later is possible.

## State and backends

- State is remote and locked from the first commit. GCS is the default
  (versioned bucket, uniform access, public access prevented). S3 with
  native locking (Terraform 1.10) or a DynamoDB lock table (1.9) is the AWS
  equivalent. GitLab-managed state (`backend "http"`) is the fastest start
  when there is no bucket yet.
- The backend block holds only the prefix; the bucket name arrives at
  `init` through `-backend-config` from `TF_BACKEND_BUCKET`. The same file
  then works for every engineer and every runner, and no environment can
  point at another's state by editing a string.
- `.terraform.lock.hcl` is committed. It pins provider hashes; without it
  two runners can plan with two provider builds.
- Address changes are written as `moved`, `import` and `removed` blocks
  (all available from 1.7), not state commands: the blocks show in the
  plan, are reviewed in the MR and run through the same pipeline apply.
  A refactor into a module is done when its plan shows moves and no
  create, destroy or replace. The blocks stay until every environment has
  applied them.
- Never `terraform state rm`, `state mv`, `import` or `taint` without a
  task id in the MR and the command in the description; they are the
  fallback when a block cannot express the change.

## Modules

- A module is a unit someone else could call. It takes typed inputs,
  returns outputs, and has no provider block of its own (the root passes
  providers down).
- Every module has `versions.tf` with `required_version = ">= 1.9"` and
  every provider pinned with `~>` to a major.
- Local modules are referenced by relative path. Registry or git modules
  carry a version or a full commit ref.
- Prefer `for_each` over `count` for anything with a name; `count` renames
  everything when one element is removed from the middle.
- A module under 300 lines of HCL. Split by concern once it grows.
- A module with validation or conditional logic has `terraform test`
  files under `tests/` in plan mode only (`command = plan`) with
  `mock_provider` blocks, so they need no credentials and create nothing.
  A test with `command = apply` creates real infrastructure: it is an
  apply, so it runs only as a manual pipeline job a person starts.

## Variables and outputs

- Every variable has `type`, `description` and at least one `validation`
  block. A string that should be an id, a region or a CIDR is validated as
  one; a number has a range; a list has a length rule.
- No `default` on a variable that differs per environment unless the
  default is the safe value. No `default` on a sensitive variable, ever.
- `sensitive = true` on every variable and output that carries a secret.
- Every output has a `description`.
- Every value another repository consumes (network ids, subnet names,
  service account emails, bucket names, cluster endpoints) is an output of
  the environment root, named for what it is.

## Providers and pinning

- `~> 6.0` style pins for providers, exact pin for Terraform in
  `.terraform-version`. `init -upgrade` is a deliberate MR titled as such.
- Provider configuration lives in the environment root only. Aliases are
  passed to modules explicitly.

## IAM and network

- Named principals, named roles. `roles/owner`, `roles/editor` and any
  `*` action or resource fail review. Grant at the resource when the
  provider allows it; project-wide grants carry a reason.
- Workload identity (GKE) or IRSA (EKS) over downloaded keys. A
  `google_service_account_key` or `aws_iam_access_key` in a plan is a
  finding.
- No `0.0.0.0/0` or `::/0` ingress. The one exception is a public load
  balancer that an ADR names; its rule carries a comment with the ADR.
- Private nodes, private database endpoints, Cloud NAT or a NAT gateway for
  egress, VPC flow logs on.

## Secrets

- Secrets live in Secret Manager (GCP) or Secrets Manager (AWS) and reach
  workloads through External Secrets or CSI drivers, never through a
  committed `Secret` manifest with `data`.
- `terraform.tfvars` is gitignored. `terraform.tfvars.example` documents
  the non-secret variables with placeholders. Secret values arrive as
  `TF_VAR_*` from the CI variable store, scoped per environment.
- `.env.example` lists every local variable with a placeholder. Cloud
  credentials come from `gcloud auth application-default login` or
  workload identity federation in CI, never from a file in the repo.

## Stateful resources

- Databases, buckets, disks, queues and clusters carry `lifecycle {
  prevent_destroy = true }` in prod. `prevent_destroy` must be a literal,
  so the prod root declares these directly (with a comment naming this
  rule) or calls a prod-only module variant.
- Deletion protection, automated backups, point-in-time recovery and
  encryption at rest are on wherever the provider makes them optional.
- A plan with `forces replacement` on a stateful resource stops the MR
  until the reviewer and the owner have both written why it is safe.

## Plan and apply

- `scripts/plan.sh <env>` is the only way a plan is produced. It writes
  `.plans/<env>.tfplan` (binary, applied later) and `.plans/<env>.txt`
  (readable, posted on the MR). `make plan ENV=<env>` calls it.
- CI plans every environment on merge requests and on `develop`, `main`
  and tags. The plan text is an exposed artifact on the MR.
- Apply is a manual job in the same pipeline, gated on that pipeline's
  plan artifact, with `resource_group` per environment so two applies
  cannot overlap. Prod apply runs only from a protected tag.
- The plan file is stale the moment state changes; Terraform refuses it,
  which is the point. Re-run the pipeline, review again, apply again.
- The agent never runs `terraform apply`, `terraform destroy` or `kubectl
  apply`, not locally, not in a script it wrote, not "just for dev".

## Kubernetes manifests

- Every container: `resources.requests` and `resources.limits`, a
  `livenessProbe` and a `readinessProbe`, `securityContext` with
  `runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation:
  false` and `capabilities.drop: [ALL]`.
- More than one replica means a PodDisruptionBudget. A HorizontalPodAutoscaler
  sets the replica range; the overlay sets `minReplicas` per environment.
- No `latest`. Dev and qa overlays pin a tag the pipeline sets; the prod
  overlay pins a digest.
- Config through a ConfigMap generated by kustomize; secrets through the
  secret manager sync, referenced by name.

## Kustomize

- `base` is complete and buildable on its own. Overlays add a namespace,
  replicas, images and patches, in that order, and nothing base already
  states unless it differs.
- Patches apply in list order. A patch that reads a field another patch
  writes comes later in the list.
- `make kustomize` builds every overlay and fails on zero resources; an
  overlay that renders nothing is a broken path, not an empty environment.
- CRDs ship in their own overlay or through the GitOps tool's ordering
  (Argo CD sync waves, Flux `dependsOn`), never mixed with the CRs that
  need them.

## GitOps hand-off

- This repository owns the manifests; a GitOps controller (Argo CD or Flux)
  owns the apply. Neither is required to start, but when one is adopted,
  the Application or Kustomization points at `k8s/overlays/<env>` on a
  branch or tag, and `kubectl apply` disappears from every pipeline.
- Until then a person applies with `kubectl apply -k k8s/overlays/<env>`
  from a reviewed MR, and says so in the MR.

## Monitoring

- Prometheus rules under `monitoring/alerts/`, one file per service, one
  group per file. Every rule has `for`, `severity`, `summary`,
  `description` and `runbook_url`.
- The runbook lives under `docs/runbooks/` (from `runbook`) before the
  rule is merged. `make lint` counts alerts against runbook links.
- Dashboards are JSON under `monitoring/dashboards/`, datasource by
  variable, never by uid. A dashboard changes in the MR that changes the
  metric.

## Local dependencies

- `docker-compose.yml` runs Postgres and Redis for engineers who test
  application code against this repo's shapes. It never runs Terraform,
  never holds a real credential; its passwords are throwaway defaults.

## Style

- `terraform fmt` decides layout; nothing a tool decides is discussed in
  review. `tflint` with the recommended preset and the provider ruleset;
  `trivy config` and checkov at MEDIUM and above. tfsec is folded into
  Trivy and no longer developed; a repository still on it moves to
  `trivy config` and carries its exclusions into `.trivyignore`.
- Terraform identifiers (resource and module labels, variables, outputs,
  locals) are lowercase with underscores, singular, and do not repeat the
  resource type; `main` when there is only one.
- Cloud resource names: lowercase, hyphenated, `<repo>-<env>-<thing>`. Labels `env`,
  `repo`, `managed_by = terraform` on everything that takes labels.
- Comments say why. A commented-out resource is deleted, not kept.
- No em dashes in comments, descriptions or docs.
