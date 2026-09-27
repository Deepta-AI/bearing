# __REPO_NAME__ (data pipeline). Every command lives here. `make help` lists them.
SHELL := /bin/bash
.DEFAULT_GOAL := help
UV ?= uv
STATE := .bearing/state
SKIPPED := $(STATE)/.skipped
# The gates `make check` runs, in order. dbt-run, dbt-test and backfill need
# a warehouse, so they are CI jobs and manual targets, not part of check.
GATES := format-check lint dbt-parse dag-test test
POSTGRES_PORT ?= 5432
# dbt reads DBT_* from the environment (profiles.yml.example); .env supplies them locally.
ENV_LOAD = set -a; [ -f .env ] && . ./.env; set +a;
# dbt finds the project and the profile through these two variables, so
# every subcommand below is plain `dbt <command>`.
export DBT_PROJECT_DIR ?= $(CURDIR)/dbt
export DBT_PROFILES_DIR ?= $(CURDIR)
DBT = $(UV) run dbt --no-use-colors
# Airflow writes its config and logs here instead of ~/airflow; git-ignored.
# The DAG folder and load_examples are set in .airflow/airflow.cfg by the
# airflow target (the AIRFLOW double-underscore variable form would trip the
# scaffold's placeholder scan); the import check passes the folder itself.
export AIRFLOW_HOME ?= $(CURDIR)/.airflow
export DBT_SEND_ANONYMOUS_USAGE_STATS ?= false

# $(call skip,gate,tool): the tool is absent. Print it, record it, and let the
# other gates run; `check` fails on any recorded skip. Never a silent pass.
define skip
{ mkdir -p $(STATE); echo "$(1): SKIPPED ($(2) not installed)"; echo "$(1) $(2)" >> $(SKIPPED); exit 0; }
endef
# $(call need_tool,gate,tool): uv, then the project tool inside the venv.
define need_tool
command -v $(UV) >/dev/null || $(call skip,$(1),uv); $(UV) run --quiet $(2) --version >/dev/null 2>&1 || $(call skip,$(1),$(2))
endef

.PHONY: help setup dev check check-file fix format format-check lint lint-dbt dbt-parse dag-test test vuln dbt-seed dbt-run dbt-test dbt-build dbt-docs backfill airflow db db-reset doctor clean

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-14s %s\n", $$1, $$2}'

setup: ## Install Python 3.12, dependencies (writes uv.lock), the local profile and git hooks
	$(UV) python install 3.12
	@if [ -f uv.lock ]; then $(UV) sync --locked --all-groups; else echo "setup: no uv.lock yet, resolving; commit the lockfile it writes"; $(UV) sync --all-groups; fi
	@[ -f profiles.yml ] || { cp profiles.yml.example profiles.yml; echo "setup: profiles.yml copied from the example (git-ignored; values come from DBT_* in .env)"; }
	bash .githooks/install.sh
	@echo "setup done"

dev: ## Compile the dbt project against the local profile (no warehouse writes)
	@$(ENV_LOAD) $(DBT) compile

format: ## ruff format and sqlfluff fix
	$(UV) run ruff format .
	@$(UV) run sqlfluff fix --force dbt/models || true

format-check: ## Fail if any Python file is unformatted
	@n=$$(git ls-files -co --exclude-standard '*.py' | wc -l | tr -d ' '); \
	[ "$$n" -gt 0 ] || { echo "format-check: 0 python files, nothing checked" >&2; exit 1; }; \
	$(call need_tool,format-check,ruff); \
	$(UV) run ruff format --check . || { echo "format-check: run make fix" >&2; exit 1; }; \
	echo "format-check: $$n files checked"

lint: ## ruff over Python, sqlfluff (jinja templater with dbt builtins, offline) over the models
	@py=$$(git ls-files -co --exclude-standard '*.py' | wc -l | tr -d ' '); \
	sql=$$(git ls-files -co --exclude-standard 'dbt/models/*.sql' | wc -l | tr -d ' '); \
	[ "$$py" -gt 0 ] && [ "$$sql" -gt 0 ] || { echo "lint: $$py python files, $$sql model files; nothing to check" >&2; exit 1; }; \
	$(call need_tool,lint,ruff); $(call need_tool,lint,sqlfluff); \
	$(UV) run ruff check . && $(UV) run sqlfluff lint dbt/models && echo "lint: $$py python files, $$sql model files checked"

lint-dbt: ## sqlfluff with the dbt templater: compiles through dbt, needs the warehouse (a CI job, not part of check)
	@sql=$$(git ls-files -co --exclude-standard 'dbt/models/*.sql' | wc -l | tr -d ' '); \
	[ "$$sql" -gt 0 ] || { echo "lint-dbt: 0 model files, nothing checked" >&2; exit 1; }; \
	[ -f profiles.yml ] || { echo "lint-dbt: no profiles.yml; run make setup" >&2; exit 1; }; \
	$(ENV_LOAD) $(UV) run sqlfluff lint --templater dbt dbt/models && echo "lint-dbt: $$sql model files checked through dbt"

dbt-parse: ## dbt parse: every model, test and macro compiles; prints the model count
	@n=$$(git ls-files -co --exclude-standard 'dbt/models/*.sql' | wc -l | tr -d ' '); \
	[ "$$n" -gt 0 ] || { echo "dbt-parse: 0 model files, nothing checked" >&2; exit 1; }; \
	$(call need_tool,dbt-parse,dbt); \
	[ -f profiles.yml ] || { echo "dbt-parse: no profiles.yml; run make setup" >&2; exit 1; }; \
	$(ENV_LOAD) $(DBT) parse --quiet || exit 1; \
	m=$$($(UV) run python -c 'import json; n=json.load(open("dbt/target/manifest.json"))["nodes"]; print(sum(1 for v in n.values() if v["resource_type"]=="model"))'); \
	[ "$$m" -gt 0 ] || { echo "dbt-parse: manifest holds 0 models" >&2; exit 1; }; \
	echo "dbt-parse: $$m models checked ($$n model files)"

dag-test: ## Import every DAG file; any import error fails
	@n=$$(git ls-files -co --exclude-standard 'dags/*.py' | grep -v '/_' | wc -l | tr -d ' '); \
	[ "$$n" -gt 0 ] || { echo "dag-test: 0 DAG files, nothing checked" >&2; exit 1; }; \
	command -v $(UV) >/dev/null || $(call skip,dag-test,uv); $(UV) run --quiet python -c 'import airflow' >/dev/null 2>&1 || $(call skip,dag-test,airflow); \
	$(UV) run python tests/dag_import_check.py

test: ## pytest over tests/ (DAG structure, dbt layout rules; no warehouse)
	@n=$$(git ls-files -co --exclude-standard 'tests/test_*.py' 'tests/**/test_*.py' | wc -l | tr -d ' '); \
	[ "$$n" -gt 0 ] || { echo "test: 0 test files, nothing checked" >&2; exit 1; }; \
	$(call need_tool,test,pytest); \
	set -o pipefail; $(UV) run pytest -m "not warehouse" 2>&1 | tail -60 && echo "test: $$n test files checked"

vuln: ## pip-audit over the locked runtime dependencies (a CI job, not part of check)
	@command -v $(UV) >/dev/null || $(call skip,vuln,uv); command -v uvx >/dev/null || $(call skip,vuln,uvx); \
	[ -f uv.lock ] || { echo "vuln: no uv.lock; run make setup and commit it" >&2; exit 1; }; \
	n=$$($(UV) export --frozen --no-dev --no-hashes --no-emit-project | grep -c '==' || true); \
	[ "$$n" -gt 0 ] || { echo "vuln: 0 packages, nothing checked" >&2; exit 1; }; \
	uvx pip-audit --strict --no-deps -r <($(UV) export --frozen --no-dev --no-hashes --no-emit-project) && echo "vuln: $$n packages checked"

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
	  *.py) command -v $(UV) >/dev/null || { echo "check-file: uv not installed, $(FILE) not checked"; exit 0; }; $(UV) run ruff check --quiet --force-exclude "$(FILE)" || exit 1;; \
	  dbt/models/*.sql) command -v $(UV) >/dev/null || { echo "check-file: uv not installed, $(FILE) not checked"; exit 0; }; $(UV) run sqlfluff lint "$(FILE)" || exit 1;; \
	  *) echo "check-file: no per-file check for $(FILE)"; exit 0;; \
	esac; \
	echo "check-file: 1 file checked"

fix: format ## Apply every automatic fix
	@$(UV) run ruff check --fix . || true

dbt-seed: ## Load the seeds into the warehouse (needs make db)
	@$(ENV_LOAD) $(DBT) seed

dbt-run: ## Build every model for the default window (needs a warehouse; a CI job, not part of check)
	@n=$$(git ls-files -co --exclude-standard 'dbt/models/*.sql' | wc -l | tr -d ' '); \
	[ "$$n" -gt 0 ] || { echo "dbt-run: 0 model files" >&2; exit 1; }; \
	$(ENV_LOAD) $(DBT) run && echo "dbt-run: $$n model files built"

dbt-test: ## Run every dbt data test (needs make dbt-seed and make dbt-run; a CI job, not part of check)
	@n=$$(git ls-files -co --exclude-standard 'dbt/models/*.yml' 'dbt/models/**/*.yml' | wc -l | tr -d ' '); \
	[ "$$n" -gt 0 ] || { echo "dbt-test: 0 schema files, nothing checked" >&2; exit 1; }; \
	$(ENV_LOAD) $(DBT) test && echo "dbt-test: tests from $$n schema files passed"

dbt-build: dbt-seed dbt-run dbt-test ## seed, run, test

dbt-docs: ## Generate the catalogue and lineage (dbt/target/manifest.json, catalog.json)
	@$(ENV_LOAD) $(DBT) docs generate
	@echo "dbt-docs: lineage in dbt/target/manifest.json; open with: $(UV) run dbt docs serve"

backfill: ## Rebuild the incremental marts for [start, end): make backfill start=2026-01-01 end=2026-02-01
	@[ -n "$(start)" ] && [ -n "$(end)" ] || { echo "usage: make backfill start=YYYY-MM-DD end=YYYY-MM-DD (end exclusive)" >&2; exit 2; }
	@expr "$(start)" \< "$(end)" >/dev/null || { echo "backfill: empty range, start $(start) is not before end $(end); nothing rebuilt" >&2; exit 2; }
	@$(ENV_LOAD) $(DBT) run --select tag:daily --vars '{"start_date": "$(start)", "end_date": "$(end)"}'
	@$(ENV_LOAD) $(DBT) test --select tag:daily --vars '{"start_date": "$(start)", "end_date": "$(end)"}'
	@echo "backfill: window $(start) to $(end) rebuilt by partition (never --full-refresh in production)"

airflow: ## Run Airflow standalone locally (UI on :8080, SQLite metadata; development only)
	@mkdir -p $(AIRFLOW_HOME); [ -f $(AIRFLOW_HOME)/airflow.cfg ] || printf '[core]\ndags_folder = %s\nload_examples = False\n' "$(CURDIR)/dags" > $(AIRFLOW_HOME)/airflow.cfg
	@$(ENV_LOAD) DBT_PROJECT_DIR=$(CURDIR)/dbt DBT_PROFILES_DIR=$(CURDIR) $(UV) run airflow standalone

db: ## Start Postgres in Docker (host port POSTGRES_PORT, default 5432)
	POSTGRES_PORT=$(POSTGRES_PORT) docker compose up -d --wait postgres

db-reset: ## Drop and recreate the local database (destructive)
	POSTGRES_PORT=$(POSTGRES_PORT) docker compose down -v && POSTGRES_PORT=$(POSTGRES_PORT) docker compose up -d --wait postgres

doctor: ## Environment diagnostics
	@echo "uv:        $$(command -v $(UV) >/dev/null && $(UV) --version || echo missing)"
	@echo "python:    $$($(UV) run python --version 2>/dev/null || echo 'missing (run make setup)')"
	@echo "dbt:       $$($(UV) run --quiet dbt --version 2>/dev/null | grep -m1 -E 'Core|installed' || echo missing)"
	@echo "airflow:   $$($(UV) run --quiet airflow version 2>/dev/null || echo missing)"
	@echo "sqlfluff:  $$($(UV) run --quiet sqlfluff --version 2>/dev/null || echo missing)"
	@echo "ruff:      $$($(UV) run --quiet ruff --version 2>/dev/null || echo missing)"
	@echo "profile:   $$([ -f profiles.yml ] && echo present || echo 'MISSING (run make setup)')"
	@echo "docker:    $$(command -v docker >/dev/null && docker --version || echo missing)"
	@echo "lock:      $$([ -f uv.lock ] && echo present || echo 'MISSING (run make setup and commit uv.lock)')"
	@echo "hooksPath: $$(git config core.hooksPath || echo 'NOT SET (run make setup)')"

clean: ## Remove caches, dbt target and Airflow state
	rm -rf .venv .ruff_cache .pytest_cache junit.xml dbt/target dbt/dbt_packages dbt/logs .airflow logs $(STATE)/.check-passed $(SKIPPED)
	find . -name __pycache__ -type d -prune -exec rm -rf {} +
