ENV ?= dev
OVERLAYS := dev qa prod

.PHONY: help check kustomize tf-check plan

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-10s %s\n", $$1, $$2}'

check: kustomize ## The local gate (Terraform checks need terraform: make tf-check)
	@echo "check: passed"

kustomize: ## Build every overlay; fail on an overlay that renders nothing
	@n=0; for o in $(OVERLAYS); do \
	  c=$$(kubectl kustomize k8s/overlays/$$o | grep -c '^kind:') || { echo "kustomize: $$o renders nothing" >&2; exit 1; }; \
	  [ "$$c" -gt 0 ] || { echo "kustomize: $$o renders nothing" >&2; exit 1; }; \
	  echo "kustomize: $$o $$c resources"; n=$$((n+1)); done; \
	[ "$$n" -gt 0 ] || { echo "kustomize: 0 overlays checked" >&2; exit 1; }; echo "kustomize: $$n overlays"

tf-check: ## fmt, init -backend=false and validate for envs/$(ENV)
	terraform fmt -check -recursive
	terraform -chdir=envs/$(ENV) init -backend=false -input=false
	terraform -chdir=envs/$(ENV) validate

plan: ## Plan envs/$(ENV) into .plans/; never applies
	@test -n "$$TF_BACKEND_BUCKET" || { echo "set TF_BACKEND_BUCKET" >&2; exit 1; }
	mkdir -p .plans
	terraform -chdir=envs/$(ENV) init -input=false -backend-config="bucket=$$TF_BACKEND_BUCKET"
	terraform -chdir=envs/$(ENV) plan -input=false -out=../../.plans/$(ENV).tfplan
	terraform -chdir=envs/$(ENV) show -no-color ../../.plans/$(ENV).tfplan > .plans/$(ENV).txt
