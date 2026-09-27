# ledger-infra

Infrastructure for the ledger service on Google Cloud: one project per
environment (dev, qa, prod), Terraform roots under `envs/`, local modules
under `modules/`, Kubernetes manifests under `k8s/` (kustomize).

## Working here

- `make check` builds every kustomize overlay and counts what it renders.
- Terraform is pinned to the version in `.terraform-version`; providers are
  pinned by the committed `.terraform.lock.hcl` in each root.
- `make tf-check ENV=dev` runs `terraform fmt -check`, `init -backend=false`
  and `validate` for one root. CI runs it for all three.
- `make plan ENV=dev` writes `.plans/dev.tfplan` and `.plans/dev.txt`. CI posts
  the text on the merge request; a person applies from the pipeline's manual
  job. Nobody applies from a laptop.
- State lives in GCS under the prefix `ledger/<env>`; the bucket name comes from
  `TF_BACKEND_BUCKET` at init.

## Address plan

Each environment owns one /16: dev 10.10.0.0/16, qa 10.20.0.0/16,
prod 10.30.0.0/16. Inside it (x = 1, 2 or 3):

| Range            | Use                                   |
|------------------|---------------------------------------|
| 10.x0.0.0/20     | GKE nodes (subnet primary range)      |
| 10.x0.16.0/20    | GKE services (secondary range)        |
| 10.x0.64.0/18    | Reserved for private service access   |
| 10.x0.128.0/17   | GKE pods (secondary range)            |

## Decisions

See `docs/adr/`.
