# __REPO_NAME__ (Node service). Every command lives here. `make help` lists them.
SHELL := /bin/bash
.DEFAULT_GOAL := help
PNPM ?= pnpm
BIN := node_modules/.bin
STATE := .bearing/state
SKIPPED := $(STATE)/.skipped
# The gates `make check` runs, in order. test-integration needs Postgres, so
# it is a CI job and a manual target, not part of check.
GATES := format-check lint typecheck test vuln
POSTGRES_PORT ?= 5432
DATABASE_URL ?= postgres://postgres:postgres@localhost:$(POSTGRES_PORT)/__REPO_SLUG__
PSQL_URL = $(DATABASE_URL)
# Files each gate looks at: tracked plus untracked, minus ignored (so a fresh scaffold counts).
SRC_FILES = $$(git ls-files -co --exclude-standard -- 'src/*.ts' 'tests/*.ts' '*.config.ts')
FMT_FILES = $$(git ls-files -co --exclude-standard -- '*.ts' '*.js' '*.json' '*.md' '*.yml' '*.yaml' | grep -Ev '^(pnpm-lock.yaml|drizzle/meta/)' | while IFS= read -r f; do [ -f "$$f" ] && [ ! -L "$$f" ] && printf '%s\n' "$$f"; done || true)
TEST_FILES = $$(git ls-files -co --exclude-standard -- 'src/*.test.ts')
INTEGRATION_FILES = $$(git ls-files -co --exclude-standard -- 'tests/integration/*.test.ts')

# $(call skip,gate,tool): the tool is absent. Print it, record it, and let the
# other gates run; `check` fails on any recorded skip. Never a silent pass.
define skip
{ mkdir -p $(STATE); echo "$(1): SKIPPED ($(2) not installed)"; echo "$(1) $(2)" >> $(SKIPPED); exit 0; }
endef

.PHONY: help setup dev build start check check-file fix test test-integration lint typecheck format format-check vuln migrate migrate-verify migrate-new migrate-status db db-reset doctor clean

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-18s %s\n", $$1, $$2}'

setup: ## Install dependencies (writes pnpm-lock.yaml) and git hooks
	@if [ -f pnpm-lock.yaml ]; then $(PNPM) install --frozen-lockfile; else echo "setup: no pnpm-lock.yaml yet, installing unfrozen; commit the lockfile it writes"; $(PNPM) install; fi
	bash .githooks/install.sh
	@echo "setup done"

dev: ## Run the API with reload (reads .env if present)
	@set -a; [ -f .env ] && . ./.env; set +a; $(PNPM) exec tsx watch src/server.ts

build: ## Compile to dist/
	$(PNPM) exec tsc -p tsconfig.build.json
	@echo "build: $$(find dist -name '*.js' | wc -l | tr -d ' ') files in dist/"

start: build ## Run the compiled server (what the image runs)
	@set -a; [ -f .env ] && . ./.env; set +a; node dist/server.js

format: ## Prettier --write
	@$(PNPM) exec prettier --log-level warn --write $(FMT_FILES)

format-check: ## Fail if any file is unformatted
	@files="$(FMT_FILES)"; n=$$(echo "$$files" | grep -c . || true); \
	[ "$$n" -gt 0 ] || { echo "format-check: 0 files, nothing checked" >&2; exit 1; }; \
	[ -x $(BIN)/prettier ] || $(call skip,format-check,prettier); \
	$(PNPM) exec prettier --log-level warn --check $$files || { echo "format-check: run make fix" >&2; exit 1; }; \
	echo "format-check: $$n files checked"

lint: ## ESLint with zero warnings allowed
	@n=$$(echo "$(SRC_FILES)" | grep -c . || true); \
	[ "$$n" -gt 0 ] || { echo "lint: 0 source files, nothing checked" >&2; exit 1; }; \
	[ -x $(BIN)/eslint ] || $(call skip,lint,eslint); \
	$(PNPM) exec eslint . --max-warnings 0 && echo "lint: $$n files checked"

typecheck: ## tsc --noEmit over src, tests and configs
	@n=$$(echo "$(SRC_FILES)" | grep -c . || true); \
	[ "$$n" -gt 0 ] || { echo "typecheck: 0 source files, nothing checked" >&2; exit 1; }; \
	[ -x $(BIN)/tsc ] || $(call skip,typecheck,tsc); \
	$(PNPM) exec tsc --noEmit -p tsconfig.json && echo "typecheck: $$n files checked"

test: ## Unit tests with coverage thresholds (vitest; no database)
	@n=$$(echo "$(TEST_FILES)" | grep -c . || true); \
	[ "$$n" -gt 0 ] || { echo "test: 0 test files, nothing checked" >&2; exit 1; }; \
	[ -x $(BIN)/vitest ] || $(call skip,test,vitest); \
	set -o pipefail; $(PNPM) exec vitest run --coverage 2>&1 | tail -60 && echo "test: $$n test files checked"

test-integration: ## Repository tests against Postgres (needs make db and make migrate; a CI job, not part of check)
	@n=$$(echo "$(INTEGRATION_FILES)" | grep -c . || true); \
	[ "$$n" -gt 0 ] || { echo "test-integration: 0 test files, nothing checked" >&2; exit 1; }; \
	[ -x $(BIN)/vitest ] || $(call skip,test-integration,vitest); \
	set -o pipefail; DATABASE_URL=$(DATABASE_URL) $(PNPM) exec vitest run --config vitest.integration.config.ts 2>&1 | tail -60 && echo "test-integration: $$n test files checked"

vuln: ## pnpm audit at high and above over the committed lockfile (production deps)
	@command -v $(PNPM) >/dev/null || $(call skip,vuln,pnpm); \
	[ -f pnpm-lock.yaml ] || { echo "vuln: no pnpm-lock.yaml; run make setup and commit it" >&2; exit 1; }; \
	$(PNPM) audit --audit-level=high --prod || exit 1; \
	n=$$($(PNPM) ls --prod --depth 100 --parseable 2>/dev/null | grep -c node_modules || true); \
	[ "$$n" -gt 0 ] || { echo "vuln: 0 packages audited" >&2; exit 1; }; echo "vuln: $$n packages checked"

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
	  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs) [ -x $(BIN)/eslint ] || { echo "check-file: eslint not installed (make setup), $(FILE) not checked"; exit 0; }; $(BIN)/eslint --max-warnings 0 "$(FILE)" || exit 1;; \
	  *) echo "check-file: no per-file check for $(FILE)"; exit 0;; \
	esac; \
	echo "check-file: 1 file checked"

fix: format ## Apply every automatic fix
	@[ -x $(BIN)/eslint ] && $(PNPM) exec eslint . --fix || true

db: ## Start Postgres in Docker (host port POSTGRES_PORT, default 5432)
	POSTGRES_PORT=$(POSTGRES_PORT) docker compose up -d --wait postgres

db-reset: ## Drop and recreate the local database (destructive)
	POSTGRES_PORT=$(POSTGRES_PORT) docker compose down -v && POSTGRES_PORT=$(POSTGRES_PORT) docker compose up -d --wait postgres

migrate: ## Apply pending migrations from drizzle/ (drizzle-kit migrate)
	DATABASE_URL=$(DATABASE_URL) $(PNPM) exec drizzle-kit migrate

migrate-verify: ## Every Down runs and restores the schema: up, snapshot, down, up, snapshot, diff (a CI step; needs psql)
	@command -v psql >/dev/null || { echo "migrate-verify: psql not installed (postgresql-client), nothing checked" >&2; exit 1; }; \
	[ -f scripts/schema-snapshot.sql ] || { echo "migrate-verify: no scripts/schema-snapshot.sql, nothing checked" >&2; exit 1; }; \
	n=$$(ls drizzle/*.sql 2>/dev/null | wc -l | tr -d ' '); \
	[ "$$n" -gt 0 ] || { echo "migrate-verify: 0 migrations in drizzle, nothing checked" >&2; exit 1; }; \
	mkdir -p $(STATE); snap() { psql "$(PSQL_URL)" -XAtq -v ON_ERROR_STOP=1 -f scripts/schema-snapshot.sql > "$(STATE)/schema-$$1.txt"; }; \
	$(MAKE) --no-print-directory migrate >/dev/null && snap up || exit 1; \
	o=$$(wc -l < $(STATE)/schema-up.txt | tr -d ' '); [ "$$o" -gt 0 ] || { echo "migrate-verify: the schema snapshot is empty, nothing compared" >&2; exit 1; }; \
	missing=0; for f in drizzle/*.sql; do [ -f "drizzle/down/$$(basename $$f)" ] || { echo "migrate-verify: no Down for $$f (write drizzle/down/$$(basename $$f))" >&2; missing=$$((missing+1)); }; done; \
	[ "$$missing" -eq 0 ] || exit 1; \
	undo() { psql "$(PSQL_URL)" -Xq -v ON_ERROR_STOP=1 -f "drizzle/down/$$1" >/dev/null && \
	  psql "$(PSQL_URL)" -Xq -v ON_ERROR_STOP=1 -c 'DELETE FROM drizzle.__drizzle_migrations WHERE id = (SELECT max(id) FROM drizzle.__drizzle_migrations)' >/dev/null; }; \
	newest=$$(ls drizzle/*.sql | sort | tail -1); undo "$$(basename $$newest)" && $(MAKE) --no-print-directory migrate >/dev/null && snap newest || exit 1; \
	diff -u $(STATE)/schema-up.txt $(STATE)/schema-newest.txt || { echo "migrate-verify: the newest Down does not undo exactly what its migration did" >&2; exit 1; }; \
	for f in $$(ls drizzle/*.sql | sort -r); do undo "$$(basename $$f)" || exit 1; done; \
	$(MAKE) --no-print-directory migrate >/dev/null && snap all || exit 1; \
	diff -u $(STATE)/schema-up.txt $(STATE)/schema-all.txt || { echo "migrate-verify: running every Down and every migration again changed the schema" >&2; exit 1; }; \
	echo "migrate-verify: $$n migrations, every Down ran, $$o schema objects identical after down and up"

migrate-new: ## Generate the next migration from src/db/schema.ts: make migrate-new name=add_invoices
	@[ -n "$(name)" ] || { echo "usage: make migrate-new name=add_invoices" >&2; exit 2; }
	$(PNPM) exec drizzle-kit generate --name "$(name)"
	@echo "migrate-new: read the SQL in drizzle/ line by line before committing"

migrate-status: ## Show which migrations the database has (drizzle-kit check compares schema and journal)
	$(PNPM) exec drizzle-kit check

doctor: ## Environment diagnostics
	@echo "node:      $$(command -v node >/dev/null && node --version || echo missing)"
	@echo "pnpm:      $$(command -v $(PNPM) >/dev/null && $(PNPM) --version 2>/dev/null || echo missing)"
	@echo "deps:      $$([ -d node_modules ] && echo installed || echo 'NOT INSTALLED (run make setup)')"
	@echo "lockfile:  $$([ -f pnpm-lock.yaml ] && echo present || echo 'MISSING (run make setup and commit pnpm-lock.yaml)')"
	@echo "tsc:       $$([ -x $(BIN)/tsc ] && $(BIN)/tsc --version || echo missing)"
	@echo "drizzle:   $$([ -x $(BIN)/drizzle-kit ] && echo present || echo missing)"
	@echo "docker:    $$(command -v docker >/dev/null && docker --version || echo missing)"
	@echo "hooksPath: $$(git config core.hooksPath || echo 'NOT SET (run make setup)')"

clean: ## Remove build and test output
	rm -rf dist coverage $(STATE)/.check-passed $(SKIPPED)
