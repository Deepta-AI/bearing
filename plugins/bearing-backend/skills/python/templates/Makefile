# __REPO_NAME__ (Python service). Every command lives here. `make help` lists them.
SHELL := /bin/bash
.DEFAULT_GOAL := help
UV ?= uv
STATE := .bearing/state
SKIPPED := $(STATE)/.skipped
# The gates `make check` runs, in order. test-integration needs Postgres, so
# it is a CI job and a manual target, not part of check.
GATES := format-check lint typecheck test vuln
POSTGRES_PORT ?= 5432
DATABASE_URL ?= postgresql+asyncpg://postgres:postgres@localhost:$(POSTGRES_PORT)/__REPO_SLUG__
# psql takes the plain URL (no SQLAlchemy driver suffix).
PSQL_URL = $(subst +asyncpg,,$(DATABASE_URL))

# $(call skip,gate,tool): the tool is absent. Print it, record it, and let the
# other gates run; `check` fails on any recorded skip. Never a silent pass.
define skip
{ mkdir -p $(STATE); echo "$(1): SKIPPED ($(2) not installed)"; echo "$(1) $(2)" >> $(SKIPPED); exit 0; }
endef
# $(call need_tool,gate,tool): uv, then the project tool inside the venv.
define need_tool
command -v $(UV) >/dev/null || $(call skip,$(1),uv); $(UV) run --quiet $(2) --version >/dev/null 2>&1 || $(call skip,$(1),$(2))
endef

.PHONY: help setup dev check check-file fix test test-integration lint typecheck format format-check migrate migrate-verify migrate-down migrate-new vuln doctor db db-reset clean

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-18s %s\n", $$1, $$2}'

setup: ## Install Python 3.14, dependencies (writes uv.lock) and git hooks
	$(UV) python install 3.14
	@if [ -f uv.lock ]; then $(UV) sync --locked --all-groups; else echo "setup: no uv.lock yet, resolving; commit the lockfile it writes"; $(UV) sync --all-groups; fi
	bash .githooks/install.sh
	@echo "setup: the committed .githooks run on commit; .pre-commit-config.yaml is for 'uv run pre-commit run --all-files'"
	@echo "setup done"

dev: ## Run the API locally with reload (reads .env if present)
	@set -a; [ -f .env ] && . ./.env; set +a; $(UV) run uvicorn app.main:create_app --factory --reload --host 0.0.0.0 --port "$${PORT:-8080}"

format: ## Format
	$(UV) run ruff format .

format-check: ## Fail if any file is unformatted
	@n=$$(git ls-files -co --exclude-standard '*.py' | wc -l | tr -d ' '); \
	[ "$$n" -gt 0 ] || { echo "format-check: 0 python files, nothing checked" >&2; exit 1; }; \
	$(call need_tool,format-check,ruff); \
	$(UV) run ruff format --check . || { echo "format-check: run make fix" >&2; exit 1; }; \
	echo "format-check: $$n files checked"

lint: ## ruff check
	@n=$$(git ls-files -co --exclude-standard '*.py' | wc -l | tr -d ' '); \
	[ "$$n" -gt 0 ] || { echo "lint: 0 python files, nothing checked" >&2; exit 1; }; \
	$(call need_tool,lint,ruff); \
	$(UV) run ruff check . && echo "lint: $$n files checked"

typecheck: ## mypy strict
	@n=$$(git ls-files -co --exclude-standard 'app/*.py' 'tests/*.py' | wc -l | tr -d ' '); \
	[ "$$n" -gt 0 ] || { echo "typecheck: 0 python files, nothing checked" >&2; exit 1; }; \
	$(call need_tool,typecheck,mypy); \
	$(UV) run mypy app tests && echo "typecheck: $$n files checked"

test: ## Unit tests with coverage (integration tests excluded)
	@n=$$(git ls-files -co --exclude-standard 'tests/test_*.py' 'tests/**/test_*.py' | grep -v '^tests/integration/' | wc -l | tr -d ' '); \
	[ "$$n" -gt 0 ] || { echo "test: 0 test files, nothing checked" >&2; exit 1; }; \
	$(call need_tool,test,pytest); \
	set -o pipefail; $(UV) run pytest -m "not integration" 2>&1 | tail -60 && echo "test: $$n test files checked"

test-integration: ## Repository tests against Postgres (needs make db and make migrate; a CI job, not part of check)
	@n=$$(git ls-files -co --exclude-standard 'tests/integration/test_*.py' | wc -l | tr -d ' '); \
	[ "$$n" -gt 0 ] || { echo "test-integration: 0 test files, nothing checked" >&2; exit 1; }; \
	set -o pipefail; DATABASE_URL=$(DATABASE_URL) $(UV) run pytest -m integration --no-cov tests/integration 2>&1 | tail -60 && echo "test-integration: $$n test files checked"

vuln: ## pip-audit over the locked runtime dependencies
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
	  *) echo "check-file: no per-file check for $(FILE)"; exit 0;; \
	esac; \
	echo "check-file: 1 file checked"

fix: format ## Apply every automatic fix
	@$(UV) run ruff check --fix . || true

db: ## Start Postgres in Docker (host port POSTGRES_PORT, default 5432)
	POSTGRES_PORT=$(POSTGRES_PORT) docker compose up -d --wait postgres

db-reset: ## Drop and recreate the local database (destructive)
	POSTGRES_PORT=$(POSTGRES_PORT) docker compose down -v && POSTGRES_PORT=$(POSTGRES_PORT) docker compose up -d --wait postgres

migrate: ## alembic upgrade head
	DATABASE_URL=$(DATABASE_URL) $(UV) run alembic upgrade head

migrate-down: ## alembic downgrade one
	DATABASE_URL=$(DATABASE_URL) $(UV) run alembic downgrade -1

migrate-verify: ## Every Down runs and restores the schema: up, snapshot, down, up, snapshot, diff (a CI step; needs psql)
	@command -v psql >/dev/null || { echo "migrate-verify: psql not installed (postgresql-client), nothing checked" >&2; exit 1; }; \
	[ -f scripts/schema-snapshot.sql ] || { echo "migrate-verify: no scripts/schema-snapshot.sql, nothing checked" >&2; exit 1; }; \
	n=$$(ls alembic/versions/*.py 2>/dev/null | wc -l | tr -d ' '); \
	[ "$$n" -gt 0 ] || { echo "migrate-verify: 0 migrations in alembic/versions, nothing checked" >&2; exit 1; }; \
	mkdir -p $(STATE); snap() { psql "$(PSQL_URL)" -XAtq -v ON_ERROR_STOP=1 -f scripts/schema-snapshot.sql > "$(STATE)/schema-$$1.txt"; }; \
	$(MAKE) --no-print-directory migrate >/dev/null && snap up || exit 1; \
	o=$$(wc -l < $(STATE)/schema-up.txt | tr -d ' '); [ "$$o" -gt 0 ] || { echo "migrate-verify: the schema snapshot is empty, nothing compared" >&2; exit 1; }; \
	$(MAKE) --no-print-directory migrate-down >/dev/null && $(MAKE) --no-print-directory migrate >/dev/null && snap newest || exit 1; \
	diff -u $(STATE)/schema-up.txt $(STATE)/schema-newest.txt || { echo "migrate-verify: the newest downgrade does not undo exactly what its upgrade did" >&2; exit 1; }; \
	DATABASE_URL=$(DATABASE_URL) $(UV) run alembic downgrade base >/dev/null && $(MAKE) --no-print-directory migrate >/dev/null && snap all || exit 1; \
	diff -u $(STATE)/schema-up.txt $(STATE)/schema-all.txt || { echo "migrate-verify: running every downgrade and every upgrade again changed the schema" >&2; exit 1; }; \
	echo "migrate-verify: $$n migrations, every downgrade ran, $$o schema objects identical after down and up"

migrate-new: ## Autogenerate the next migration: make migrate-new name=add_invoices
	@[ -n "$(name)" ] || { echo "usage: make migrate-new name=add_invoices" >&2; exit 2; }
	@id=$$(printf '%04d' $$(( $$(ls alembic/versions/*.py 2>/dev/null | wc -l) + 1 ))); \
	DATABASE_URL=$(DATABASE_URL) $(UV) run alembic revision --autogenerate --rev-id "$$id" -m "$(name)" && \
	echo "migrate-new: alembic/versions/$${id}_$(name).py written; read every line before committing"

doctor: ## Environment diagnostics
	@echo "uv:        $$(command -v $(UV) >/dev/null && $(UV) --version || echo missing)"
	@echo "python:    $$($(UV) run python --version 2>/dev/null || echo 'missing (run make setup)')"
	@echo "ruff:      $$($(UV) run --quiet ruff --version 2>/dev/null || echo missing)"
	@echo "mypy:      $$($(UV) run --quiet mypy --version 2>/dev/null || echo missing)"
	@echo "alembic:   $$($(UV) run --quiet alembic --version 2>/dev/null || echo missing)"
	@echo "docker:    $$(command -v docker >/dev/null && docker --version || echo missing)"
	@echo "lock:      $$([ -f uv.lock ] && echo present || echo 'MISSING (run make setup and commit uv.lock)')"
	@echo "hooksPath: $$(git config core.hooksPath || echo 'NOT SET (run make setup)')"

clean: ## Remove caches and build output
	rm -rf .venv .ruff_cache .mypy_cache .pytest_cache .coverage htmlcov dist build $(STATE)/.check-passed $(SKIPPED)
	find . -name __pycache__ -type d -prune -exec rm -rf {} +
