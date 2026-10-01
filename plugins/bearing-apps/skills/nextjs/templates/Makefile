# __REPO_NAME__ (Next.js app). Every command lives here. `make help` lists them.
SHELL := /bin/bash
.DEFAULT_GOAL := help
PNPM ?= pnpm
BIN := node_modules/.bin
STATE := .bearing/state
SKIPPED := $(STATE)/.skipped
# The gates `make check` runs, in order. build needs minutes and test-e2e
# needs a browser and a production build, so both are CI jobs and manual
# targets, not part of check.
GATES := design-registry-check format-check lint typecheck test vuln
# Files each gate looks at: tracked plus untracked, minus ignored (so a fresh scaffold counts).
SRC_FILES = $$(git ls-files -co --exclude-standard -- 'src/*.ts' 'src/*.tsx' 'e2e/*.ts' '*.config.ts' '*.config.mjs')
FMT_FILES = $$(git ls-files -co --exclude-standard -- '*.ts' '*.tsx' '*.js' '*.mjs' '*.json' '*.css' '*.md' '*.yml' '*.yaml' | grep -v '^pnpm-lock.yaml$$' || true)
TEST_FILES = $$(git ls-files -co --exclude-standard -- 'src/*.test.ts' 'src/*.test.tsx')
E2E_FILES = $$(git ls-files -co --exclude-standard -- 'e2e/*.spec.ts' | grep -v '^e2e/visual/' || true)
VISUAL_FILES = $$(git ls-files -co --exclude-standard -- 'e2e/visual/*.spec.ts')
# Every browser and device project in playwright.config.ts except visual.
MATRIX := --project=chromium --project=firefox --project=webkit --project=mobile-chrome --project=mobile-safari
PW_VERSION = $$(sed -n 's/.*"@playwright\/test": "\([^"]*\)".*/\1/p' package.json)
# Page budgets: gzipped JavaScript the build ships, and lighthouserc.json for
# LCP, CLS and total blocking time. A fresh scaffold ships 276 KB, so the
# budget leaves room for growth and catches a heavy dependency; lower it to
# the measured size plus headroom once the app exists, and raise it only in
# the MR that needs it, with the reason.
BUNDLE_BUDGET_KB ?= 350
export NEXT_TELEMETRY_DISABLED := 1

# $(call skip,gate,tool): the tool is absent. Print it, record it, and let the
# other gates run; `check` fails on any recorded skip. Never a silent pass.
define skip
{ mkdir -p $(STATE); echo "$(1): SKIPPED ($(2) not installed)"; echo "$(1) $(2)" >> $(SKIPPED); exit 0; }
endef

# $(call in_pw_image,gate,command): run a pnpm command inside the Playwright
# image for this repository's @playwright/test version, with node_modules in a
# volume of its own. Screenshots made anywhere else differ in fonts and fail CI.
define in_pw_image
{ command -v docker >/dev/null || { echo "$(1): docker is required; screenshots taken outside the Playwright image differ from CI" >&2; exit 1; }; \
  v=$(PW_VERSION); [ -n "$$v" ] || { echo "$(1): no @playwright/test version in package.json" >&2; exit 1; }; \
  docker run --rm --ipc=host -v "$$PWD:/work" -v /work/node_modules -w /work "mcr.microsoft.com/playwright:v$$v-noble" \
    bash -c "corepack enable && pnpm install --frozen-lockfile --silent && $(2); s=\$$?; chown -R $$(id -u):$$(id -g) e2e test-results playwright-report dist .next 2>/dev/null; exit \$$s"; }
endef

.PHONY: help setup dev design-registry design-registry-check build start check check-file fix test test-e2e test-e2e-matrix test-visual test-visual-update setup-browsers bundle-budget lighthouse lint typecheck format format-check vuln doctor clean

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-14s %s\n", $$1, $$2}'

setup: ## Install dependencies (writes pnpm-lock.yaml), Playwright chromium and git hooks
	@if [ -f pnpm-lock.yaml ]; then $(PNPM) install --frozen-lockfile; else echo "setup: no pnpm-lock.yaml yet, installing unfrozen; commit the lockfile it writes"; $(PNPM) install; fi
	$(PNPM) exec playwright install chromium
	bash .githooks/install.sh
	@echo "setup done"

dev: design-registry ## Run the Next dev server on :3000 (reads .env.local if present); the design gallery is at /__design
	$(PNPM) exec next dev --port 3000

design-registry: ## Rewrite src/design/screens.generated.ts from the *.screen.tsx files and design variants
	@node scripts/design-registry.mjs

design-registry-check: ## Fail when src/design/screens.generated.ts is stale (a screen added without make design-registry)
	@n=$$(find src/features -path '*/screens/*.screen.tsx' 2>/dev/null | wc -l | tr -d ' '); \
	[ "$$n" -gt 0 ] || { echo "design-registry-check: 0 screen files under src/features/*/screens, nothing checked" >&2; exit 1; }; \
	command -v node >/dev/null || $(call skip,design-registry-check,node); \
	node scripts/design-registry.mjs --check >/dev/null && echo "design-registry-check: $$n screen files checked"

build: ## Production build (standalone output in .next/standalone)
	@mkdir -p $(STATE); rm -f $(STATE)/.build-passed
	$(PNPM) exec next build
	@echo "build: $$(find .next/standalone -type f 2>/dev/null | wc -l | tr -d ' ') files in .next/standalone"
	@touch $(STATE)/.build-passed

start: ## Serve the standalone build on :3000, as the image does (run make build first)
	PORT=3000 $(PNPM) run start

format: ## Prettier --write
	@$(PNPM) exec prettier --log-level warn --write $(FMT_FILES)

format-check: ## Fail if any file is unformatted
	@files="$(FMT_FILES)"; n=$$(echo "$$files" | grep -c . || true); \
	[ "$$n" -gt 0 ] || { echo "format-check: 0 files, nothing checked" >&2; exit 1; }; \
	[ -x $(BIN)/prettier ] || $(call skip,format-check,prettier); \
	$(PNPM) exec prettier --log-level warn --check $$files || { echo "format-check: run make fix" >&2; exit 1; }; \
	echo "format-check: $$n files checked"

lint: ## ESLint (eslint-config-next plus strict type-checked rules) with zero warnings allowed
	@n=$$(echo "$(SRC_FILES)" | grep -c . || true); \
	[ "$$n" -gt 0 ] || { echo "lint: 0 source files, nothing checked" >&2; exit 1; }; \
	[ -x $(BIN)/eslint ] || $(call skip,lint,eslint); \
	$(PNPM) exec eslint . --max-warnings 0 && echo "lint: $$n files checked"

typecheck: ## tsc --noEmit
	@n=$$(echo "$(SRC_FILES)" | grep -c . || true); \
	[ "$$n" -gt 0 ] || { echo "typecheck: 0 source files, nothing checked" >&2; exit 1; }; \
	[ -x $(BIN)/tsc ] || $(call skip,typecheck,tsc); \
	$(PNPM) exec tsc --noEmit -p tsconfig.json && echo "typecheck: $$n files checked"

test: ## Unit tests with coverage thresholds (vitest, jsdom, Testing Library)
	@n=$$(echo "$(TEST_FILES)" | grep -c . || true); \
	[ "$$n" -gt 0 ] || { echo "test: 0 test files, nothing checked" >&2; exit 1; }; \
	[ -x $(BIN)/vitest ] || $(call skip,test,vitest); \
	set -o pipefail; $(PNPM) exec vitest run --coverage 2>&1 | tail -60 && echo "test: $$n test files checked"

test-e2e: ## Playwright on chromium against a production build on :3000 (needs a browser; a CI job, not part of check)
	@n=$$(echo "$(E2E_FILES)" | grep -c . || true); \
	[ "$$n" -gt 0 ] || { echo "test-e2e: 0 spec files, nothing checked" >&2; exit 1; }; \
	[ -x $(BIN)/playwright ] || $(call skip,test-e2e,playwright); \
	$(PNPM) exec playwright test --project=chromium && echo "test-e2e: $$n spec files checked on 1 project"

test-e2e-matrix: ## The same specs on chromium, firefox, webkit and two phones (CI after merge; make setup-browsers first)
	@n=$$(echo "$(E2E_FILES)" | grep -c . || true); \
	[ "$$n" -gt 0 ] || { echo "test-e2e-matrix: 0 spec files, nothing checked" >&2; exit 1; }; \
	[ -x $(BIN)/playwright ] || $(call skip,test-e2e-matrix,playwright); \
	$(PNPM) exec playwright test $(MATRIX) && echo "test-e2e-matrix: $$n spec files checked on $(words $(MATRIX)) projects"

setup-browsers: ## Install every Playwright browser the matrix needs (setup installs chromium only)
	$(PNPM) exec playwright install firefox webkit

test-visual: ## Screenshot comparison of e2e/visual/ against the committed baselines, inside the Playwright image unless in CI (a CI job)
	@n=$$(echo "$(VISUAL_FILES)" | grep -c . || true); \
	[ "$$n" -gt 0 ] || { echo "test-visual: 0 visual specs in e2e/visual/, nothing checked" >&2; exit 1; }; \
	if [ -n "$$CI" ]; then $(PNPM) exec playwright test --project=visual || exit 1; \
	else $(call in_pw_image,test-visual,pnpm exec playwright test --project=visual) || exit 1; fi; \
	echo "test-visual: $$n visual specs checked"

test-visual-update: ## Rewrite the visual baselines inside the Playwright image (Docker) so fonts match CI; commit them on their own
	@n=$$(echo "$(VISUAL_FILES)" | grep -c . || true); \
	[ "$$n" -gt 0 ] || { echo "test-visual-update: 0 visual specs in e2e/visual/, nothing to update" >&2; exit 1; }; \
	$(call in_pw_image,test-visual-update,pnpm exec playwright test --project=visual --update-snapshots) || exit 1; \
	echo "test-visual-update: $$n visual specs; review every changed png in e2e/__screenshots__/ before committing"

bundle-budget: ## Gzipped JavaScript in .next/static/chunks/ under BUNDLE_BUDGET_KB (run make build first)
	@[ -d .next/static/chunks ] || { echo "bundle-budget: no .next/static/chunks/; run make build first" >&2; exit 1; }; \
	n=0; total=0; for f in $$(find .next/static/chunks -name '*.js' -type f); do n=$$((n+1)); total=$$((total + $$(gzip -c "$$f" | wc -c))); done; \
	[ "$$n" -gt 0 ] || { echo "bundle-budget: 0 JavaScript files in .next/static/chunks/, nothing checked" >&2; exit 1; }; \
	kb=$$((total / 1024)); echo "bundle-budget: $$n files, $$kb KB gzipped, budget $(BUNDLE_BUDGET_KB) KB"; \
	[ "$$kb" -le "$(BUNDLE_BUDGET_KB)" ] || { echo "bundle-budget: over budget by $$((kb - $(BUNDLE_BUDGET_KB))) KB" >&2; exit 1; }

lighthouse: ## Lighthouse CI against the production build: fails on the assertions in lighthouserc.json (needs Chrome or Playwright's chromium)
	@[ -f lighthouserc.json ] || { echo "lighthouse: no lighthouserc.json, nothing checked" >&2; exit 1; }; \
	n=$$(grep -o '"http[^"]*"' lighthouserc.json | wc -l | tr -d ' '); \
	[ "$$n" -gt 0 ] || { echo "lighthouse: 0 URLs in lighthouserc.json, nothing checked" >&2; exit 1; }; \
	command -v $(PNPM) >/dev/null || $(call skip,lighthouse,pnpm); \
	c="$${CHROME_PATH:-$$(find "$${PLAYWRIGHT_BROWSERS_PATH:-$$HOME/.cache/ms-playwright}" /ms-playwright -type f -name chrome -path '*chromium-*' 2>/dev/null | head -1)}"; \
	[ -n "$$c" ] || { echo "lighthouse: no Chrome found; run make setup or set CHROME_PATH" >&2; exit 1; }; \
	CHROME_PATH="$$c" $(PNPM) dlx @lhci/cli@0.15.1 autorun --config=lighthouserc.json && \
	echo "lighthouse: $$n pages checked against lighthouserc.json"

vuln: ## pnpm audit at high and above over the committed lockfile (production deps)
	@command -v $(PNPM) >/dev/null || $(call skip,vuln,pnpm); \
	[ -f pnpm-lock.yaml ] || { echo "vuln: no pnpm-lock.yaml; run make setup and commit it" >&2; exit 1; }; \
	out=$$($(PNPM) audit --audit-level=high --prod 2>&1); rc=$$?; echo "$$out"; \
	if [ $$rc -ne 0 ] && echo "$$out" | grep -qiE 'ENOTFOUND|EAI_AGAIN|ECONNREFUSED|ETIMEDOUT|fetch failed|AUDIT_ENDPOINT_NOT_EXISTS|BAD_RESPONSE'; then mkdir -p $(STATE); echo "vuln: SKIPPED (package registry unreachable; nothing audited)"; echo "vuln registry" >> $(SKIPPED); exit 0; fi; \
	[ $$rc -eq 0 ] || exit 1; \
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

doctor: ## Environment diagnostics
	@echo "node:       $$(command -v node >/dev/null && node --version || echo missing)"
	@echo "pnpm:       $$(command -v $(PNPM) >/dev/null && $(PNPM) --version 2>/dev/null || echo missing)"
	@echo "deps:       $$([ -d node_modules ] && echo installed || echo 'NOT INSTALLED (run make setup)')"
	@echo "lockfile:   $$([ -f pnpm-lock.yaml ] && echo present || echo 'MISSING (run make setup and commit pnpm-lock.yaml)')"
	@echo "next:       $$([ -x $(BIN)/next ] && $(BIN)/next --version 2>/dev/null || echo missing)"
	@echo "tsc:        $$([ -x $(BIN)/tsc ] && $(BIN)/tsc --version || echo missing)"
	@echo "playwright: $$([ -x $(BIN)/playwright ] && $(BIN)/playwright --version || echo missing)"
	@echo "browsers:   $$(ls "$${PLAYWRIGHT_BROWSERS_PATH:-$$HOME/.cache/ms-playwright}" 2>/dev/null | grep -c chromium || echo 0) chromium builds"
	@echo "docker:     $$(command -v docker >/dev/null && docker --version || echo missing)"
	@echo "hooksPath:  $$(git config core.hooksPath || echo 'NOT SET (run make setup)')"

clean: ## Remove build and test output
	rm -rf .next coverage playwright-report test-results .lighthouseci tsconfig.tsbuildinfo $(STATE)/.check-passed $(STATE)/.build-passed $(SKIPPED)
