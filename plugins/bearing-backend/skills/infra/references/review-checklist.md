# Infra review checklist

For each item, either find the concrete failure or write "none found". Read
the posted plan before the diff: the plan is what will happen.

## The plan
- Provenance first: the plan's commit is the branch head, and there is a
  plan for every environment the change reaches. A commit after the plan
  or a missing environment means that part is unplanned; review it from
  the code and ask for fresh plans before approval.
- A stateful resource (database, bucket, disk, queue, cluster) destroyed or
  replaced, hidden among many lines; `forces replacement` on anything in
  prod. Read the `Plan:` summary line before the body.
- A plan or diff that contradicts the MR description ("no data changes"
  beside a replacement): quote both.
- A plan that touches an environment the MR does not claim to touch.
- Drift: changes in the plan that the diff does not explain (console edits,
  a provider upgrade, a data source that changed its answer).
- A plan produced with `-refresh=false`, `-target`, or a local state file.
- A Terraform address change (rename of a resource label, module move)
  that destroys and recreates instead of carrying a `moved` block; a
  `state mv` or `state rm` where a `moved` or `removed` block would do.
- A change to a cloud resource's own `name` (instance, bucket, secret id,
  cluster): that forces replacement, and no `moved`, `state mv` or import
  can avoid it. The fix is to keep the existing name. Never propose a
  `moved` block for it.
- A `terraform test` file with `command = apply` outside a manual job.

## IAM breadth
- A wildcard action or resource (`*`, `roles/owner`, `roles/editor`,
  `iam.serviceAccountTokenCreator` project-wide).
- A role granted at project or account level that a resource-level binding
  would cover; name what else in the project that role opens (every
  secret, every bucket).
- An authoritative grant (`*_iam_policy`, `*_iam_binding`): it removes
  members granted anywhere else, and two for the same role fight on every
  apply. Additive `*_iam_member` unless this code owns the role outright.
- A service account with a downloaded key (`google_service_account_key`,
  `aws_iam_access_key`) instead of workload identity.

## Public exposure
- `0.0.0.0/0` or `::/0` ingress without a documented public load balancer;
  a public IP on a node, a database or a bucket; `public_access_prevention`
  missing on a bucket.
- A Service of type `LoadBalancer` or an Ingress without TLS.

## Encryption and backups
- A disk, database, bucket, queue or snapshot without encryption at rest
  where the provider makes it optional.
- A database without automated backups, point-in-time recovery or deletion
  protection; a bucket without versioning where it holds state or data.
  A `deletion_protection` that comes from a variable defaulting to false.
- A copy stored outside the required location: backup location, secret
  replication, bucket or dataset location, replica region left to a
  provider default.
- Missing `lifecycle { prevent_destroy = true }` on a stateful resource in
  prod.

## Pinning and drift
- An unpinned or `>=` provider; a module `source` without a version or a
  ref; `.terraform.lock.hcl` deleted or not committed.
- A container image with `latest`, a moving tag, or a tag in prod where a
  digest is required.
- A `data` source that depends on something outside the repo (a "latest"
  image lookup, a name search) that will change the plan silently.

## Secrets
- A value in `terraform.tfvars`, `*.auto.tfvars`, a `default` on a sensitive
  variable, a `Secret` manifest with `data` or `stringData`, or a
  credential in a compose file that is not a throwaway local default.
- A sensitive output without `sensitive = true`; a secret logged by a
  `null_resource` or a provisioner.
- A generated secret stored in state (`random_password`, a user password,
  `secret_data`) without the report saying so; a provider or Terraform
  version bump the change did not need.

## Kubernetes
- A workload without requests and limits, without liveness and readiness
  probes, or with more than one replica in any overlay and no
  PodDisruptionBudget.
- A probe the process cannot answer: open the entrypoint and find the
  listener, port and handler paths the probe names.
- An `images:` entry whose `name` does not equal the base image string
  exactly: the pin silently does nothing. Render each overlay and read
  the image lines.
- A container running as root, privileged, with a writable root filesystem
  or without `capabilities: drop: [ALL]`.
- An overlay that builds zero resources, a patch whose target does not
  exist, a CR whose CRD is not shipped first.
- A HorizontalPodAutoscaler and a fixed `replicas` fighting each other.

## Observability
- An alert rule without `runbook_url`, or with a link to a runbook that does
  not exist under `docs/runbooks/`.
- An alert on a metric or label nothing exports: grep the code for the
  metric name. An alert that can never fire is worse than none.
- An alert without `for`, or with a threshold nobody can defend; a
  dashboard JSON with a hard-coded datasource uid.

## Pipeline
- An apply that is not `when: manual`, not gated on the plan artifact of the
  same pipeline, or missing `resource_group`.
- Prod apply reachable from an unprotected branch or tag.
- A job that runs `terraform destroy`, `state rm` or `kubectl apply`.

## Hygiene
- A `trivy`, `tflint` or `checkov` rule excluded without a task id and a
  reason beside it.
- A variable without a type, description or validation; an output another
  repo needs that is missing.
- A shell script that is not shellcheck clean, or that applies.
- Em dash in a comment, a description or a doc.
