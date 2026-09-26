# __REPO_NAME__

Infrastructure repository. `make help` lists every command; `make check` is
the gate. CI plans and posts the plan; a person applies. Nothing here
applies on its own.

## Environments

| Environment | Directory   | State prefix | Applied from            |
| ----------- | ----------- | ------------ | ----------------------- |
| dev         | `envs/dev`  | `envs/dev`   | `develop`, manual job   |
| qa          | `envs/qa`   | `envs/qa`    | `main`, manual job      |
| prod        | `envs/prod` | `envs/prod`  | protected tag, manual   |

Each environment is a root module with its own backend prefix, values and
pipeline jobs. The three stay structurally identical; only values differ.

## State backend

`envs/<env>/backend.tf` carries a `__BACKEND__` block with the GCS backend
active and the S3 backend beside it, commented. The `cloud` key of the
`tech-decision` record for this repository says which one the project uses;
switch all three environments in one MR, together with the provider block
in `main.tf`. The bucket name is never in the file: `make init` and CI pass
it from `TF_BACKEND_BUCKET`.

## Plan

```
cp .env.example .env          # project, region, state bucket
make setup                    # tool versions, tflint plugins, git hooks
make init ENV=dev             # terraform init against the remote backend
make plan ENV=dev             # .plans/dev.tfplan and .plans/dev.txt
make check                    # fmt, validate, lint, sec (trivy config + checkov), kustomize, shell
```

`make check` prints one `<gate>: N ... checked` line per gate and a final
tally. A gate whose tool is missing prints `SKIPPED` and the tally fails;
`BEARING_ALLOW_SKIP=1 make check` lets a laptop without every scanner through
and is never set in CI.

Open a merge request. The pipeline runs the same gates and `scripts/plan.sh`
for every environment and exposes the plan text on the MR. Review the plan
before the diff: a destroyed or replaced stateful resource is the first
line of the review.

## Apply (a person, never the agent)

1. Merge. The pipeline on `develop` (dev), `main` (qa) or a protected tag
   (prod) plans again and stops at a manual `apply-<env>` job.
2. Read `.plans/<env>.txt` from that pipeline's artifacts. If it differs
   from the MR plan, stop and find out why.
3. Run the manual job. It applies that pipeline's plan file, under a
   `resource_group` lock, and the `verify-<env>` job reads the state back.
4. A stale plan fails the apply. Re-run the pipeline, review again.

There is no `make apply` and no `terraform apply` in any script on purpose.

## Add a module

1. `modules/<name>/` with `main.tf`, `variables.tf` (type, description,
   validation on every variable), `outputs.tf`, `versions.tf` (pinned).
2. `make docs` writes the inputs and outputs table into the module's
   `README.md` with terraform-docs; commit it with the module.
3. Call it from `envs/dev/main.tf` first, plan, review, apply in dev; then
   qa, then prod, each in its own MR.
4. Export what other repositories need from `envs/<env>/outputs.tf`.

## Kubernetes and monitoring

`k8s/base` is the workload; `k8s/overlays/<env>` sets namespace, replicas
and image (tag in dev and qa, digest in prod). `make kustomize` builds every
overlay. Alerts live in `monitoring/alerts/`, each with a `runbook_url`
into `docs/runbooks/`; dashboards in `monitoring/dashboards/`.

See `AGENTS.md` and the `infra` skill for the conventions.
