# ledger-service

The ledger API and its infrastructure.

- `cmd/api`: HTTP API (port 8080, `/healthz`, `/readyz`).
- `internal/ledger`: posting rules.
- `infra/`: Terraform (one root per environment under `infra/envs/`, modules
  under `infra/modules/`) and kustomize manifests under `infra/k8s/`.
- `monitoring/alerts/`: Prometheus rules; every rule links a runbook under
  `docs/runbooks/`.

`make check` runs go vet, go test and builds every kustomize overlay.
CI plans every environment on a merge request and posts the plan text; a
person applies from the pipeline's manual job after the MR is approved.
