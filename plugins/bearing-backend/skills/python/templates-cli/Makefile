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

.PHONY: help setup run build check check-file check-changed fix fmt test lint typecheck format format-check vuln doctor clean

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

check-file: ## Lint one edited file, FILE=path (run it in the session after an edit; no Bearing hook runs it)
	@[ -n "$(FILE)" ] || { echo "check-file: FILE is empty, nothing checked" >&2; exit 1; }; \
	[ -f "$(FILE)" ] || { echo "check-file: $(FILE) does not exist, nothing checked" >&2; exit 1; }; \
	case "$(FILE)" in \
	  *.py) command -v $(UV) >/dev/null || { echo "check-file: uv not installed, $(FILE) not checked"; exit 0; }; $(UV) run ruff check --quiet --force-exclude "$(FILE)" || exit 1;; \
	  *) echo "check-file: no per-file check for $(FILE)"; exit 0;; \
	esac; \
	echo "check-file: 1 file checked"

CHANGED = git status --porcelain -z --untracked-files=all | tr '\0' '\n' | awk 'skip{skip=0;next} {c=substr($$0,1,2);p=substr($$0,4)} c~/^R|^.R|^C/{print p;skip=1;next} {print p}' | sort -u | while IFS= read -r f; do [ -e "$$f" ] || continue; for m in $(STATE)/.check-passed $(STATE)/.check-changed-passed; do [ -f "$$m" ] && ! [ "$$f" -nt "$$m" ] && continue 2; done; printf '%s\n' "$$f"; done

check-changed: ## ruff format check, ruff check and pytest on the tests for the changed modules only (the Bearing Stop gate runs this; make check stays the full gate)
	@mkdir -p $(STATE); files=$$($(CHANGED) | grep -E '\.py$$|pyproject\.toml$$|uv\.lock$$' || true); \
	f=$$(printf '%s' "$$files" | grep -c . || true); \
	[ "$$f" -gt 0 ] || { touch $(STATE)/.check-changed-passed; echo "check-changed: 0 files, nothing to check"; exit 0; }; \
	py=$$(printf '%s\n' "$$files" | grep '\.py$$' || true); \
	[ -z "$$py" ] || { $(UV) run ruff format --check $$py && $(UV) run ruff check $$py; } || exit 1; \
	if printf '%s\n' "$$files" | grep -qE 'pyproject\.toml$$|uv\.lock$$|conftest\.py$$'; then tests=""; \
	else tests=$$(for x in $$py; do case "$$x" in (tests/*test_*.py) echo "$$x";; (*) b=$$(basename "$$x" .py); git ls-files -co --exclude-standard "tests/test_$$b.py" "tests/**/test_$$b.py";; esac; done | sort -u); \
	  [ -n "$$tests" ] || { touch $(STATE)/.check-changed-passed; echo "check-changed: $$f files, 0 packages checked (no tests map to them; make check runs all)"; exit 0; }; fi; \
	p=$$(printf '%s' "$$tests" | grep -c . || true); [ -n "$$tests" ] || p=all; \
	set -o pipefail; $(UV) run pytest --no-cov $$tests 2>&1 | tail -60; rc=$$?; [ $$rc -eq 0 ] || [ $$rc -eq 5 ] || exit 1; [ $$rc -ne 5 ] || p=0; \
	touch $(STATE)/.check-changed-passed; echo "check-changed: $$f files, $$p packages checked"

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
