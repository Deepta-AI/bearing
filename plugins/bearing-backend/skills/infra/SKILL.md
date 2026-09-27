---
name: infra
description: 'Infrastructure house rules (Terraform modules, remote state, per-env dirs, tflint, Trivy, kustomize, plan-only CI). Load before changing Terraform or k8s. Use when asked about "remote state", "a kustomize overlay".'
allowed-tools: Read, Grep, Glob, Skill, Bash(terraform fmt:*), Bash(terraform validate:*), Bash(terraform plan:*), Bash(tflint:*), Bash(trivy config:*), Bash(kustomize build:*), Bash(make:*)
---

# infra

The infrastructure stack on this standard: Terraform >= 1.9 with local modules and
remote locked state (GCS by default, S3 or GitLab-managed as documented
alternatives), one directory per environment, `tflint`, `trivy config`
(the IaC scanner that absorbed tfsec) with checkov, Kubernetes manifests
with kustomize, Prometheus alert rules, Grafana dashboard JSON, docker
compose for local dependencies, `shellcheck` for scripts. The rule that defines the stack: CI runs `plan` and posts it; a
person runs `apply` from that pipeline. The agent never applies.

**Decisions first.** Before building, run `bearing:tech-decision` for the keys
cloud, compute, iac, ci, secrets, ingress, backups. `bearing:tech-decision` asks only about the keys this task needs that no
accepted ADR, the request or the code already settles, one question at
a time, and records only what the user decides; a key still
awaiting an answer follows the decision protocol of the
`bearing:tech-decision` skill (references/decision-protocol.md in the
bearing plugin).

## Inputs

- Terraform, Kubernetes and monitoring files: the repository as it is; no scaffold is needed. A
  different layout is handled under "On a foreign layout".
- Gate: `make check` when a Makefile has that target; else the native
  commands under Commands, one by one.
- `references/guidelines.md` and `references/review-checklist.md` ship
  with this skill. `bearing:new-repo` and `bearing:ci-pipeline` are suggestions for a
  repository without a Makefile or a pipeline, never prerequisites.
- Decisions: `docs/adr/` and the code itself (provider block, backend,
  CI file) answer most `bearing:tech-decision` keys on an existing repository;
  only the open keys are asked.

## When this skill is active

- Writing or changing `.tf`, `.tfvars`, `k8s/**` or monitoring files: apply
  `references/guidelines.md`. Read it once per session, then work.
- Reviewing a diff with infrastructure files: apply
  `references/review-checklist.md` and report every finding as severity (Critical, High, Medium, Low), `file:line`, the claim, a concrete failure scenario and the fix, then list what was checked and found clean and what was not reviewed.
  A plan that destroys or replaces anything is the first line of the review.
- Pack skills (hashicorp/agent-skills), when installed, cover three
  narrow jobs; load them with the Skill tool: `terraform-test` to
  write `.tftest.hcl` files, `terraform-refactor-module` to split a root
  into modules, `terraform-style-guide` for HCL layout and naming. This
  skill still owns everything they do not: state, environments, IAM,
  secrets, Kubernetes, alerts, the gates and the plan. Where they differ,
  this skill's rules apply: tests are plan mode with mock providers only; a
  refactor ends at a reviewed plan that shows moves and no replacement,
  never at the pack's `terraform apply`; module files keep `versions.tf`
  over the pack's `terraform.tf`. The agent never applies, whatever a
  pack skill says. Pack not installed: the same jobs follow
  `references/guidelines.md`.
- Scaffolding (`new-repo infra <Name>`): `templates/` holds the skeleton
  and configs; `bin/brg-scaffold` in the bearing plugin copies them. Do not hand-copy.
- Generating CI (`bearing:ci-pipeline`): `templates/.gitlab-ci.yml` is the source.

## Layout

```
modules/<name>/           main.tf variables.tf outputs.tf versions.tf, one concern each
envs/{dev,qa,prod}/       main.tf backend.tf variables.tf outputs.tf terraform.tfvars.example
k8s/base/                 kustomization.yaml deployment service pdb hpa
k8s/overlays/{dev,qa,prod}/  kustomization.yaml: namespace, replicas, image tag or digest
monitoring/alerts/        Prometheus rule files, every alert with runbook_url
monitoring/dashboards/    Grafana dashboard JSON, one file per service
scripts/                  bash, shellcheck clean; plan.sh is the only plan entry point
docs/runbooks/            one runbook per alert (runbook), linked from the rule
Makefile                  the only entry point: help setup init plan check fix doctor
```

Directory-per-environment rather than workspaces: each environment has its
own state, backend prefix, credentials, variable values and pipeline job,
so a wrong `workspace select` cannot plan dev values against prod state, an
MR diff shows exactly which environment changes, and environments can pin
different module versions during a rollout.

## On a foreign layout

Hard rules anywhere: 1, 3, 4, 6, 7 and 8. Advisory: directory per
environment (workspaces already in use stay, with an ADR to move),
local modules, kustomize (Helm charts map rule 6 to values) and the
Makefile targets. Say which rule was relaxed and why.

## Rules that matter most

1. State is remote and locked. No local state, no `-refresh=false`, no
   `state rm` or `state mv` without a task id in the MR.
2. No resource without a module or a comment saying why it is declared in
   the environment root (`prevent_destroy` must be literal, so prod
   stateful resources are the usual reason).
3. Least-privilege IAM: named principals, named roles, no wildcard actions,
   no `roles/owner` or `roles/editor`. No `0.0.0.0/0` ingress except a
   documented public load balancer.
4. Every secret comes from a secret manager. A tfvars file with a value in
   it is never committed; `terraform.tfvars` is gitignored, the `.example`
   holds only non-secret placeholders.
5. Every variable has a type, a description and a validation. Every value
   another repository consumes is an output.
6. Every Kubernetes workload has requests and limits, liveness and readiness
   probes, and a PodDisruptionBudget when it runs more than one replica.
   No `latest` tag anywhere; prod overlays pin the image digest.
7. Every alert rule has a `runbook_url` annotation and the runbook exists
   before the rule is merged.
8. The plan is reviewed in the MR. A person applies from the manual job of
   the same pipeline, with that pipeline's plan file. The agent never runs
   `apply`, `destroy` or `kubectl apply`.
9. `make check` = fmt-check, validate, lint, sec, kustomize, shell. CI runs
   the same targets.

## Traps that look fine on reading

Each of these passes a read of the diff and `make check`; each has taken
data or production down. Check them on every change and every review.

- **Compute per environment, from the code.** Ranges, names and sizes are
  read from each `envs/<env>` root on its own; roots drift (a prod-only
  second pod range, a qa override), and a README address plan or a
  pattern from dev is a claim, not the source. A new CIDR is checked
  against every range that root and its modules declare.
- **A cloud name is not a Terraform address.** Changing `name` on a
  Cloud SQL instance, bucket, secret, cluster or disk forces replacement:
  a new empty resource and the old one destroyed with its data. `moved`,
  `state mv` and `import` change only addresses; they cannot rename
  anything in the cloud. The fix is to keep the existing name (or a
  planned migration), and deletion protection stays on.
- **Data residency is per attribute.** A region on the resource does not
  place its copies. Set them: Cloud SQL `backup_configuration.location`
  (the default is a multi-region), Secret Manager `user_managed`
  replication (automatic is global), bucket and dataset `location`, KMS
  key ring location, replica regions.
- **Private IP needs private service access.** One reserved
  `VPC_PEERING` range per VPC from that environment's own block, a
  `google_service_networking_connection`, and the instance depends on
  the connection. Cloud SQL for PostgreSQL 16 and later defaults to the
  Enterprise Plus edition, which rejects `db-custom-*` tiers: set
  `edition = "ENTERPRISE"` with them (point-in-time log retention is at
  most 7 days on Enterprise).
- **Generated secrets land in state.** `random_password.result`,
  `google_sql_user.password` and `secret_data` are stored in clear in
  the state file. Write-only arguments (`password_wo`, `secret_data_wo`,
  Terraform 1.11+) and ephemeral resources avoid it, but only on
  versions the repository's pins allow. Either stay within the pins and
  say the state holds the secret (state readers are secret readers), or
  propose the upgrade as its own change. Never raise `required_version`,
  a provider constraint or `.terraform-version` as a side effect; any
  provider added or bumped means the committed lock files must be
  regenerated with `terraform init`, and the report says so.
- **Authoritative IAM removes grants.** `*_iam_policy` owns a resource's
  whole policy and `*_iam_binding` owns every member of one role: an apply
  strips members granted elsewhere, and two bindings for the same role
  overwrite each other forever. Use `*_iam_member` unless this code owns
  the role outright. Grant at the resource (one secret, one bucket), not
  the project, when the resource supports it.
- **Manifests must match the code they run.** A probe's port and path
  exist only if the process serves them (find the listener and handlers);
  an alert's metric exists only if something exports it with those
  labels. A worker with no HTTP server and an HTTP probe never becomes
  Ready; an alert on a metric nobody exports never fires.
- **Render, then read.** A kustomize `images:` entry applies only when its
  `name` equals the image string in the base exactly; a mismatch is
  silent and ships the base image untagged (`latest`). Read the image,
  replicas and namespace lines of `kubectl kustomize` for every overlay;
  a resource count proves nothing.
- **A plan is evidence only for the commit it came from.** Before
  trusting a posted plan, match its commit to the branch head and check
  there is one for every environment the change touches. Commits after
  the plan, or a missing environment, are unreviewed; read them as if
  no plan existed. The summary line (`N to destroy`) is read first.
- **Say what ran.** Name each gate that ran with its result and each that
  could not run, with the reason checked (is the binary really missing?).
  No commit unless asked; never set a git author or committer identity.

## Commands

Each target is used when the Makefile has it; the command after the
colon is the native form to run without one.

```
make setup            # tool version checks, tflint plugins, git hooks
make init ENV=dev     # terraform -chdir=envs/dev init
make plan ENV=dev     # terraform -chdir=envs/dev plan -out=.plans/dev.tfplan, never applies
make check            # terraform fmt -check -recursive ; validate after init -backend=false ; tflint ; trivy config envs modules ; checkov ; kustomize build k8s/overlays/<env> ; shellcheck scripts/*.sh
make fix              # terraform fmt -recursive
make kustomize        # kustomize build k8s/overlays/<env>, count resources
make doctor           # versions of every tool
```

## Gotchas

- The templates cover Google Cloud with Kubernetes and kustomize; when
  the decisions choose otherwise, the ADR lists what to adapt and the
  scaffold is not applied blindly.
- Pin providers with `~>` in every `versions.tf`; an unpinned provider
  upgrades on the next `init -upgrade` and rewrites the plan.
- Drift: a plan that shows changes you did not make means someone clicked
  in the console. Import or revert, never `-refresh=false` to hide it.
- kustomize applies patches in list order after resources; a patch that
  targets a field another patch creates must come after it.
- CRDs before CRs: a `kustomize build` succeeds with a CR whose CRD is not
  installed, and the apply fails. Ship CRDs in a separate overlay or the
  GitOps app's sync wave.
- `prevent_destroy` on every stateful resource in prod; a plan with
  `forces replacement` on one of them is a stop, not a note.
- GitLab-managed Terraform state (`backend "http"`) is the fastest start:
  no bucket to create, locking included, one init command from the docs.
  Move to GCS or S3 when more than one project shares the state.
- `terraform validate` needs `init -backend=false`; the Makefile does this
  so validation never needs cloud credentials.
