# __REPO_NAME__ (React Native app, Expo). Every command lives here. `make help` lists them.
SHELL := /bin/bash
.DEFAULT_GOAL := help
PNPM := pnpm
BIN := node_modules/.bin
STATE := .bearing/state
SKIPPED := $(STATE)/.skipped
# The gates `make check` runs, in order. test-e2e needs a simulator or a
# device with the app installed, so it is a manual target, not part of check.
GATES := format-check lint typecheck test vuln
SRC_GLOB := app src
# Files Prettier and ESLint own: tracked plus untracked, honouring .gitignore.
CODE_FILES = $$(git ls-files -co --exclude-standard -- '*.ts' '*.tsx' '*.js' '*.json' '*.css' '*.md' | grep -Ev '^(dist|ios|android|coverage)/')
TS_FILES = $$(git ls-files -co --exclude-standard -- 'app/*.ts' 'app/*.tsx' 'src/*.ts' 'src/*.tsx')

# $(call skip,gate,tool): the tool is absent. Print it, record it, and let the
# other gates run; `check` fails on any recorded skip. Never a silent pass.
define skip
{ mkdir -p $(STATE); echo "$(1): SKIPPED ($(2) not installed)"; echo "$(1) $(2)" >> $(SKIPPED); exit 0; }
endef

.PHONY: help setup dev ios android check check-file fix test test-e2e lint typecheck format format-check vuln doctor build-preview export clean

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-18s %s\n", $$1, $$2}'

setup: ## Install dependencies (writes pnpm-lock.yaml) and git hooks
	@if [ -f pnpm-lock.yaml ]; then $(PNPM) install --frozen-lockfile; else echo "setup: no pnpm-lock.yaml yet, installing unfrozen; commit the lockfile it writes"; $(PNPM) install; fi
	bash .githooks/install.sh
	@echo "setup done"

dev: ## Start the Metro dev server (Expo Go or a dev client)
	@set -a; [ -f .env ] && . ./.env; set +a; $(PNPM) exec expo start

ios: ## Build and run a dev client on the iOS simulator (needs macOS and Xcode)
	@command -v xcodebuild >/dev/null || { echo "ios: xcodebuild missing; iOS needs macOS with Xcode or an EAS build" >&2; exit 1; }
	$(PNPM) exec expo run:ios

android: ## Build and run a dev client on an Android emulator or device
	@[ -n "$$ANDROID_HOME" ] || [ -n "$$ANDROID_SDK_ROOT" ] || { echo "android: ANDROID_HOME not set; install Android Studio and the SDK" >&2; exit 1; }
	$(PNPM) exec expo run:android

format: ## Prettier write
	$(PNPM) exec prettier --write --log-level warn $(CODE_FILES)

format-check: ## Fail if any file is unformatted
	@files="$(CODE_FILES)"; n=$$(printf '%s\n' $$files | grep -c . || true); \
	[ "$$n" -gt 0 ] || { echo "format-check: 0 files, nothing checked" >&2; exit 1; }; \
	[ -x $(BIN)/prettier ] || $(call skip,format-check,prettier); \
	$(PNPM) exec prettier --check --log-level warn $$files || { echo "format-check: run make fix" >&2; exit 1; }; \
	echo "format-check: $$n files checked"

lint: ## ESLint, zero warnings
	@n=$$(printf '%s\n' $(TS_FILES) | grep -c . || true); \
	[ "$$n" -gt 0 ] || { echo "lint: 0 ts files under app/ and src/, nothing checked" >&2; exit 1; }; \
	[ -x $(BIN)/eslint ] || $(call skip,lint,eslint); \
	$(PNPM) exec eslint . --max-warnings 0 && echo "lint: $$n files checked"

typecheck: ## tsc --noEmit (strict)
	@n=$$(printf '%s\n' $(TS_FILES) | grep -c . || true); \
	[ "$$n" -gt 0 ] || { echo "typecheck: 0 ts files, nothing checked" >&2; exit 1; }; \
	[ -x $(BIN)/tsc ] || $(call skip,typecheck,tsc); \
	$(PNPM) exec tsc --noEmit && echo "typecheck: $$n files checked"

test: ## Jest unit tests with coverage (jest-expo)
	@n=$$(git ls-files -co --exclude-standard -- '*.test.ts' '*.test.tsx' | grep -c . || true); \
	[ "$$n" -gt 0 ] || { echo "test: 0 test files, nothing checked" >&2; exit 1; }; \
	[ -x $(BIN)/jest ] || $(call skip,test,jest); \
	$(PNPM) exec jest --ci --coverage 2>&1 | tail -60; \
	st=$${PIPESTATUS[0]}; [ "$$st" -eq 0 ] || exit $$st; echo "test: $$n test files checked"

test-e2e: ## Maestro flows in .maestro/ (needs a running simulator or device with the app installed; not part of check)
	@n=$$(ls .maestro/*.yaml 2>/dev/null | wc -l | tr -d ' '); \
	[ "$$n" -gt 0 ] || { echo "test-e2e: 0 flows in .maestro/, nothing checked" >&2; exit 1; }; \
	command -v maestro >/dev/null || $(call skip,test-e2e,maestro); \
	maestro test .maestro && echo "test-e2e: $$n flows checked"

# The count comes from the audit's own metadata: `pnpm ls --depth 100` over the
# Expo 57 graph runs Node out of heap and would report 0 packages.
vuln: ## pnpm audit at high and above over the committed lockfile (production deps)
	@command -v $(PNPM) >/dev/null || $(call skip,vuln,pnpm); \
	[ -f pnpm-lock.yaml ] || { echo "vuln: no pnpm-lock.yaml; run make setup and commit it" >&2; exit 1; }; \
	$(PNPM) audit --audit-level high --prod || exit 1; \
	n=$$($(PNPM) audit --prod --json 2>/dev/null | node -e 'let s="";process.stdin.on("data",c=>s+=c).on("end",()=>{try{console.log(JSON.parse(s).metadata.totalDependencies)}catch{console.log(0)}})' || true); n=$${n:-0}; \
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

fix: ## Apply every automatic fix
	$(PNPM) exec prettier --write --log-level warn $(CODE_FILES)
	$(PNPM) exec eslint . --fix || true

export: ## Bundle JS and assets for both platforms into dist/ (no native build)
	$(PNPM) exec expo export --platform ios --platform android --output-dir dist
	@echo "export: $$(find dist/assets -type f 2>/dev/null | wc -l | tr -d ' ') assets"

build-preview: ## EAS preview build for both platforms; runs only with EAS_CONFIRM=1
	@cmd="pnpm dlx eas-cli build --profile preview --platform all"; \
	if [ "$$EAS_CONFIRM" = "1" ]; then $$cmd; \
	else echo "build-preview: builds cost EAS credit and are the engineer's call."; \
	  echo "  run: EAS_CONFIRM=1 make build-preview"; echo "  or:  $$cmd"; exit 1; fi

doctor: ## Environment diagnostics
	@echo "node:      $$(node --version 2>/dev/null || echo missing)"
	@echo "pnpm:      $$(pnpm --version 2>/dev/null || echo missing)"
	@echo "lockfile:  $$([ -f pnpm-lock.yaml ] && echo present || echo 'MISSING (run make setup and commit pnpm-lock.yaml)')"
	@echo "expo:      $$($(PNPM) exec expo --version 2>/dev/null || echo missing)"
	@echo "eas:       $$(command -v eas >/dev/null && eas --version 2>/dev/null | head -1 || echo 'missing (pnpm dlx eas-cli)')"
	@echo "maestro:   $$(command -v maestro >/dev/null && maestro --version 2>/dev/null | head -1 || echo missing)"
	@echo "watchman:  $$(command -v watchman >/dev/null && watchman --version || echo missing)"
	@echo "java:      $$(command -v java >/dev/null && java -version 2>&1 | head -1 || echo 'missing (Android builds)')"
	@echo "android:   $${ANDROID_HOME:-$${ANDROID_SDK_ROOT:-NOT SET}}"
	@echo "xcode:     $$(command -v xcodebuild >/dev/null && xcodebuild -version | head -1 || echo 'missing (iOS builds need macOS)')"
	@echo "hooksPath: $$(git config core.hooksPath || echo 'NOT SET (run make setup)')"
	@echo "expo-doctor (npx, not pnpm exec: pnpm's npm_config_* env makes doctor's npm subprocess warn and fail):"
	npx expo-doctor

clean: ## Remove build output and caches
	rm -rf dist coverage .expo ios android $(STATE)/.check-passed $(SKIPPED)
