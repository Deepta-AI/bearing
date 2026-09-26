# __REPO_NAME__ (Python CLI). Every command lives here. `make help` lists them.
SHELL := /bin/bash
.DEFAULT_GOAL := help
UV ?= uv
STATE := .bearing/state
SKIPPED := $(STATE)/.skipped
# The gates `make check` runs, in order.
GATES := format-check lint typecheck test vuln
# Arguments for `make run`: make run ARGS="lines README.md"
ARGS ?= --help

# $(call skip,gate,tool): the tool is absent. Print it, record it, and let the
# other gates run; `check` fails on any recorded skip. Never a silent pass.
define skip
{ mkdir -p $(STATE); echo "$(1): SKIPPED ($(2) not installed)"; echo "$(1) $(2)" >> $(SKIPPED); exit 0; }
endef
# $(call need_tool,gate,tool): uv, then the project tool inside the venv.
define need_tool
command -v $(UV) >/dev/null || $(call skip,$(1),uv); $(UV) run --quiet $(2) --version >/dev/null 2>&1 || $(call skip,$(1),$(2))
endef

.PHONY: help setup run build check check-file fix fmt test lint typecheck format format-check vuln doctor clean

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-18s %s\n", $$1, $$2}'

setup: ## Install Python 3.14, dependencies (writes uv.lock) and git hooks
	$(UV) python install 3.14
	@if [ -f uv.lock ]; then $(UV) sync --locked --all-groups; else echo "setup: no uv.lock yet, resolving; commit the lockfile it writes"; $(UV) sync --all-groups; fi
	bash .githooks/install.sh
	@echo "setup: the committed .githooks run on commit; .pre-commit-config.yaml is for 'uv run pre-commit run --all-files'"
	@echo "setup done"

run: ## Run the tool from the venv: make run ARGS="lines README.md"
	$(UV) run __REPO_SLUG__ $(ARGS)

build: ## Build the wheel and sdist into dist/
	@rm -rf dist
	$(UV) build
	@n=$$(ls dist/*.whl dist/*.tar.gz 2>/dev/null | wc -l | tr -d ' '); \
	[ "$$n" -gt 0 ] || { echo "build: 0 artifacts in dist/, nothing built" >&2; exit 1; }; \
	echo "build: $$n artifacts built in dist/"

format: ## Format
	$(UV) run ruff format .

fmt: format ## Alias of format

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
	@n=$$(git ls-files -co --exclude-standard 'src/*.py' 'tests/*.py' | wc -l | tr -d ' '); \
	[ "$$n" -gt 0 ] || { echo "typecheck: 0 python files, nothing checked" >&2; exit 1; }; \
	$(call need_tool,typecheck,mypy); \
	$(UV) run mypy src tests && echo "typecheck: $$n files checked"

test: ## Unit tests with coverage
	@n=$$(git ls-files -co --exclude-standard 'tests/test_*.py' 'tests/**/test_*.py' | wc -l | tr -d ' '); \
	[ "$$n" -gt 0 ] || { echo "test: 0 test files, nothing checked" >&2; exit 1; }; \
	$(call need_tool,test,pytest); \
	set -o pipefail; $(UV) run pytest 2>&1 | tail -60 && echo "test: $$n test files checked"

# The tool has no runtime dependencies, so the audit covers every locked
# package, dev tools included: they run on engineers' machines and in CI.
vuln: ## pip-audit over every locked dependency (runtime and dev)
	@command -v $(UV) >/dev/null || $(call skip,vuln,uv); command -v uvx >/dev/null || $(call skip,vuln,uvx); \
	[ -f uv.lock ] || { echo "vuln: no uv.lock; run make setup and commit it" >&2; exit 1; }; \
	n=$$($(UV) export --frozen --all-groups --no-hashes --no-emit-project | grep -c '==' || true); \
	[ "$$n" -gt 0 ] || { echo "vuln: 0 packages, nothing checked" >&2; exit 1; }; \
	uvx pip-audit --strict --no-deps -r <($(UV) export --frozen --all-groups --no-hashes --no-emit-project) && echo "vuln: $$n packages checked"

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

doctor: ## Environment diagnostics
	@echo "uv:        $$(command -v $(UV) >/dev/null && $(UV) --version || echo missing)"
	@echo "python:    $$($(UV) run python --version 2>/dev/null || echo 'missing (run make setup)')"
	@echo "ruff:      $$($(UV) run --quiet ruff --version 2>/dev/null || echo missing)"
	@echo "mypy:      $$($(UV) run --quiet mypy --version 2>/dev/null || echo missing)"
	@echo "tool:      $$($(UV) run --quiet __REPO_SLUG__ --version 2>/dev/null || echo 'missing (run make setup)')"
	@echo "lock:      $$([ -f uv.lock ] && echo present || echo 'MISSING (run make setup and commit uv.lock)')"
	@echo "hooksPath: $$(git config core.hooksPath || echo 'NOT SET (run make setup)')"

clean: ## Remove caches and build output
	rm -rf .venv .ruff_cache .mypy_cache .pytest_cache .coverage coverage.xml junit.xml htmlcov dist build $(STATE)/.check-passed $(SKIPPED)
	find . -name __pycache__ -type d -prune -exec rm -rf {} +
