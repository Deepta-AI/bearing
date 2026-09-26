---
name: infra
description: 'Conventions for infrastructure code: Terraform modules and remote state, per-environment directories, tflint, Trivy, kustomize, plan-only CI. Use when writing or reviewing "Terraform", "k8s manifests" or "infra".'
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
  `references/review-checklist.md` and report in the reviewer format.
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
