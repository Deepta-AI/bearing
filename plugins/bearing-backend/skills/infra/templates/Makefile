# __REPO_NAME__ (infrastructure). Every command lives here. `make help` lists them.
# There is no apply target. CI plans and posts the plan; a person applies from
# the pipeline's manual job with that pipeline's plan file. See README.md.
SHELL := /bin/bash
.DEFAULT_GOAL := help
ENV ?= dev
ENVS := dev qa prod
ENV_DIRS := $(addprefix envs/,$(ENVS))
MODULE_DIRS := $(wildcard modules/*)
OVERLAYS := $(wildcard k8s/overlays/*)
PLANS := .plans
STATE := .bearing/state
SKIPPED := $(STATE)/.skipped
# The gates `make check` runs, in order. None needs a cloud credential.
GATES := fmt-check validate lint sec kustomize shell
TF_REQUIRED := $(shell cat .terraform-version 2>/dev/null || echo 1.9.0)

# $(call skip,gate,tool): the tool is absent. Print it, record it, and let the
# other gates run; `check` fails on any recorded skip. Never a silent pass.
define skip
{ mkdir -p $(STATE); echo "$(1): SKIPPED ($(2) not installed)"; echo "$(1) $(2)" >> $(SKIPPED); exit 0; }
endef
# $(call need,tool,gate): skip the gate when the tool is absent.
define need
command -v $(1) >/dev/null || $(call skip,$(2),$(1))
endef

.PHONY: help setup init plan apply destroy check check-file fix fmt fmt-check validate lint sec kustomize shell docs doctor clean deps deps-down

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-14s %s\n", $$1, $$2}'

setup: ## Check tool versions, init tflint plugins, install git hooks
	@missing=0; \
	for t in terraform tflint trivy checkov kustomize shellcheck terraform-docs; do \
	  if command -v $$t >/dev/null; then echo "  $$t: ok"; else echo "  $$t: MISSING"; missing=$$((missing+1)); fi; \
	done; \
	if command -v terraform >/dev/null; then \
	  have=$$(terraform version -json | sed -n 's/.*"terraform_version": *"\([^"]*\)".*/\1/p'); \
	  low=$$(printf '%s\n%s\n' "$(TF_REQUIRED)" "$$have" | sort -V | head -1); \
	  [ "$$low" = "$(TF_REQUIRED)" ] || { echo "terraform $$have is older than $(TF_REQUIRED) (.terraform-version)" >&2; exit 1; }; \
	  echo "  terraform $$have >= $(TF_REQUIRED)"; \
	fi; \
	command -v tflint >/dev/null && tflint --init --config "$(CURDIR)/.tflint.hcl" || true; \
	bash .githooks/install.sh; \
	[ "$$missing" -eq 0 ] || echo "setup: $$missing tool(s) missing. terraform: tfenv or hashicorp.com; tflint, trivy, kustomize, shellcheck, terraform-docs: brew or the GitHub releases; checkov: pipx install checkov"; \
	echo "setup done"

init: ## terraform init for ENV (default dev) against the remote backend
	@set -a; [ -f .env ] && . ./.env; set +a; \
	[ -n "$$TF_BACKEND_BUCKET" ] || { echo "init: TF_BACKEND_BUCKET is not set (see .env.example)" >&2; exit 1; }; \
	terraform -chdir=envs/$(ENV) init -input=false -reconfigure -backend-config="bucket=$$TF_BACKEND_BUCKET"

plan: ## terraform plan for ENV; writes $(PLANS)/$(ENV).tfplan and .txt, never applies
	bash scripts/plan.sh $(ENV)

# No apply here on purpose. A plan applied from a laptop was never the plan
# the reviewer read. Apply is the manual job in the pipeline that produced
# the plan, gated on that pipeline's plan artifact, run by a person.
apply: ## Not here: a person applies from the pipeline's manual job
	@echo "apply: this Makefile has no apply target on purpose." >&2
	@echo "CI plans and posts the plan; a person runs the manual apply-$(ENV) job of that" >&2
	@echo "same pipeline, which applies its own plan artifact. The agent never applies." >&2
	@echo "See README.md, section Apply." >&2
	@exit 1

destroy: ## Not here either
	@echo "destroy: not from a Makefile. Open an MR that removes the code, review the plan." >&2
	@exit 1

fmt: ## Format every .tf and .tfvars file
	terraform fmt -recursive

fmt-check: ## Fail if any file is unformatted
	@n=$$(find envs modules -name '*.tf' -not -path '*/.terraform/*' | wc -l | tr -d ' '); \
	[ "$$n" -gt 0 ] || { echo "fmt-check: 0 tf files, nothing checked" >&2; exit 1; }; \
	$(call need,terraform,fmt-check); \
	terraform fmt -check -recursive -diff || { echo "fmt-check: run make fix" >&2; exit 1; }; \
	echo "fmt-check: $$n files checked"

validate: ## terraform validate every env and module (init without backend)
	@n=$$(echo $(ENV_DIRS) $(MODULE_DIRS) | wc -w | tr -d ' '); [ "$$n" -gt 0 ] || { echo "validate: 0 directories, nothing checked" >&2; exit 1; }; \
	$(call need,terraform,validate); \
	for d in $(ENV_DIRS) $(MODULE_DIRS); do \
	  terraform -chdir=$$d init -backend=false -input=false >/dev/null || { echo "validate: init failed in $$d" >&2; exit 1; }; \
	  terraform -chdir=$$d validate || exit 1; \
	done; echo "validate: $$n directories checked"

lint: ## tflint over every env and module, then alerts against runbook links
	@n=$$(find envs modules -name '*.tf' -not -path '*/.terraform/*' | wc -l | tr -d ' '); \
	[ "$$n" -gt 0 ] || { echo "lint: 0 tf files, nothing checked" >&2; exit 1; }; \
	alerts=$$(cat monitoring/alerts/*.yaml 2>/dev/null | grep -c '^ *- alert:' || true); \
	runbooks=$$(cat monitoring/alerts/*.yaml 2>/dev/null | grep -c '^ *runbook_url:' || true); \
	[ "$$alerts" -gt 0 ] || { echo "lint: 0 alert rules in monitoring/alerts, nothing checked" >&2; exit 1; }; \
	[ "$$alerts" -eq "$$runbooks" ] || { echo "lint: $$alerts alerts but $$runbooks runbook_url annotations" >&2; exit 1; }; \
	echo "lint: $$alerts alerts checked, $$runbooks runbook links"; \
	$(call need,tflint,lint); \
	tflint --init --config "$(CURDIR)/.tflint.hcl" >/dev/null; \
	tflint --recursive --config "$(CURDIR)/.tflint.hcl" || exit 1; \
	echo "lint: $$n tf files checked"

# Two scanners with different rule sets over the Terraform tree: trivy config
# (which absorbed tfsec and its rules; tfsec is no longer developed) and
# checkov. Exclusions live in .trivyignore and .checkov.yaml. Neither scans
# k8s/, where trivy's trusted-registry rule rejects GitLab and Artifact
# Registry hosts.
sec: ## trivy config and checkov over envs and modules at MEDIUM and above
	@n=$$(find envs modules -name '*.tf' -not -path '*/.terraform/*' | wc -l | tr -d ' '); \
	[ "$$n" -gt 0 ] || { echo "sec: 0 tf files, nothing checked" >&2; exit 1; }; \
	$(call need,trivy,sec); \
	for d in envs modules; do trivy config --quiet --exit-code 1 --severity MEDIUM,HIGH,CRITICAL --ignorefile .trivyignore --skip-dirs '**/.terraform' $$d || exit 1; done; \
	echo "sec: $$n tf files checked (trivy)"; \
	$(call need,checkov,sec); \
	checkov --directory envs --directory modules --framework terraform --quiet --compact --config-file .checkov.yaml || exit 1; \
	echo "sec: $$n tf files checked (checkov)"

kustomize: ## Build every overlay; fail if any builds zero resources
	@n=$$(echo $(OVERLAYS) | wc -w | tr -d ' '); [ "$$n" -gt 0 ] || { echo "kustomize: 0 overlays, nothing checked" >&2; exit 1; }; \
	if command -v kustomize >/dev/null; then build="kustomize build"; \
	elif command -v kubectl >/dev/null; then build="kubectl kustomize"; \
	else $(call skip,kustomize,kustomize); fi; \
	total=0; for o in $(OVERLAYS); do \
	  out=$$($$build "$$o") || { echo "kustomize: $$o failed to build" >&2; exit 1; }; \
	  c=$$(printf '%s\n' "$$out" | grep -c '^kind:'); \
	  [ "$$c" -gt 0 ] || { echo "kustomize: $$o built 0 resources" >&2; exit 1; }; \
	  echo "  $$o: $$c resources"; total=$$((total+c)); \
	done; echo "kustomize: $$n overlays checked, $$total resources"

shell: ## shellcheck every script
	@n=$$(ls scripts/*.sh 2>/dev/null | wc -l | tr -d ' '); [ "$$n" -gt 0 ] || { echo "shell: 0 scripts, nothing checked" >&2; exit 1; }; \
	$(call need,shellcheck,shell); \
	shellcheck -x scripts/*.sh && echo "shell: $$n scripts checked"

docs: ## terraform-docs: write the inputs and outputs table into each module's README.md
	@n=$$(echo $(MODULE_DIRS) | wc -w | tr -d ' '); [ "$$n" -gt 0 ] || { echo "docs: 0 modules" >&2; exit 1; }; \
	command -v terraform-docs >/dev/null || { echo "docs: terraform-docs missing (brew install terraform-docs or the GitHub release)" >&2; exit 1; }; \
	for d in $(MODULE_DIRS); do terraform-docs markdown table --output-file README.md --output-mode inject "$$d" >/dev/null || exit 1; done; \
	echo "docs: $$n module READMEs written"

check: ## The gate: every gate in GATES, then the tally. CI runs exactly this.
	@mkdir -p $(STATE); rm -f $(SKIPPED) $(STATE)/.check-passed
	@for g in $(GATES); do $(MAKE) --no-print-directory $$g || { echo "check: $$g failed" >&2; exit 1; }; done
	@s=$$(cut -d' ' -f1 $(SKIPPED) 2>/dev/null | sort -u | wc -l | tr -d ' '); r=$$(( $(words $(GATES)) - s )); \
	echo "check: $$r gates run, $$s skipped"; \
	if [ "$$s" -eq 0 ]; then touch $(STATE)/.check-passed; echo "check: passed"; \
	elif [ "$${BEARING_ALLOW_SKIP:-0}" = "1" ] && [ -z "$$CI" ]; then sed 's/^/  skipped: /' $(SKIPPED); echo "check: passed with skips (BEARING_ALLOW_SKIP=1 is a local convenience; CI never sets it)"; \
	else sed 's/^/  skipped: /' $(SKIPPED); echo "check: FAILED, $$s gate(s) skipped; run make setup, or BEARING_ALLOW_SKIP=1 make check locally" >&2; exit 1; fi

check-file: ## Lint one edited file, FILE=path (the Bearing edit hook runs this)
	@[ -n "$(FILE)" ] || { echo "check-file: FILE is empty, nothing checked" >&2; exit 1; }; \
	[ -f "$(FILE)" ] || { echo "check-file: $(FILE) does not exist, nothing checked" >&2; exit 1; }; \
	case "$(FILE)" in \
	  *.tf) command -v tflint >/dev/null || { echo "check-file: tflint not installed, $(FILE) not checked"; exit 0; }; tflint --chdir="$$(dirname "$(FILE)")" --config "$(CURDIR)/.tflint.hcl" || exit 1;; \
	  *.sh) command -v shellcheck >/dev/null || { echo "check-file: shellcheck not installed, $(FILE) not checked"; exit 0; }; shellcheck "$(FILE)" || exit 1;; \
	  *) echo "check-file: no per-file check for $(FILE)"; exit 0;; \
	esac; \
	echo "check-file: 1 file checked"

fix: fmt ## Apply every automatic fix

deps: ## Start local dependencies (Postgres, Redis) in Docker
	docker compose up -d

deps-down: ## Stop local dependencies and drop their volumes (destructive)
	docker compose down -v

doctor: ## Environment diagnostics
	@echo "terraform:      $$(command -v terraform >/dev/null && terraform version | head -1 || echo missing) (required $(TF_REQUIRED))"
	@echo "tflint:         $$(command -v tflint >/dev/null && tflint --version | head -1 || echo missing)"
	@echo "trivy:          $$(command -v trivy >/dev/null && trivy --version | head -1 || echo missing)"
	@echo "checkov:        $$(command -v checkov >/dev/null && checkov --version || echo missing)"
	@echo "kustomize:      $$(command -v kustomize >/dev/null && kustomize version || echo missing)"
	@echo "kubectl:        $$(command -v kubectl >/dev/null && kubectl version --client 2>/dev/null | head -1 || echo missing)"
	@echo "shellcheck:     $$(command -v shellcheck >/dev/null && shellcheck --version | sed -n 's/^version: //p' || echo missing)"
	@echo "terraform-docs: $$(command -v terraform-docs >/dev/null && terraform-docs --version || echo missing)"
	@echo "docker:         $$(command -v docker >/dev/null && docker --version || echo missing)"
	@echo "backend:        $${TF_BACKEND_BUCKET:-NOT SET (see .env.example)}"
	@echo "hooksPath:      $$(git config core.hooksPath || echo 'NOT SET (run make setup)')"

clean: ## Remove plans, provider downloads and crash logs (never state)
	rm -rf $(PLANS) crash.log crash.*.log $(STATE)/.check-passed $(SKIPPED)
	find envs modules -type d -name .terraform -prune -exec rm -rf {} +
