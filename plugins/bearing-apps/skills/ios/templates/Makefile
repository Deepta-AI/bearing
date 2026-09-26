# __REPO_NAME__ (iOS app). Every command lives here. `make help` lists them.
# `make check` is the gate on every platform: format, lint and the package
# tests run on Linux and macOS; the Xcode build is a gate too and is SKIPPED
# (which fails check) where xcodebuild is absent.
SHELL := /bin/bash
.DEFAULT_GOAL := help
APP := __REPO_NAME__
KIT := Packages/__REPO_NAME__Kit
PROJECT := $(APP).xcodeproj
SCHEME ?= $(APP)
STATE := .bearing/state
SKIPPED := $(STATE)/.skipped
# The gates `make check` runs, in order. test-ui needs a simulator, so it is
# a CI job on a Mac runner and a manual target, not part of check.
GATES := format-check lint test build
# Simulator for test-ui: SIMULATOR=... overrides; otherwise the first available
# iPhone is resolved at run time (see resolve_simulator).
SIMULATOR ?=
SWIFT_DIRS := App $(KIT)/Package.swift $(KIT)/Sources $(KIT)/Tests
# The simulator build product; the build gate fails when it is not written.
SIM_APP := build/DerivedData/Build/Products/Debug-iphonesimulator/$(APP).app

# $(call skip,gate,tool): the tool is absent. Print it, record it, and let the
# other gates run; `check` fails on any recorded skip. Never a silent pass.
define skip
{ mkdir -p $(STATE); echo "$(1): SKIPPED ($(2) not installed)"; echo "$(1) $(2)" >> $(SKIPPED); exit 0; }
endef
# $(call resolve_simulator,target): sets $$sim to SIMULATOR or the first
# available iPhone; fails with the list command when there is none.
define resolve_simulator
sim="$(SIMULATOR)"; \
if [ -z "$$sim" ]; then sim=$$(xcrun simctl list devices available 2>/dev/null | grep -o 'iPhone [0-9]* Pro\|iPhone [0-9]*' | head -1); fi; \
[ -n "$$sim" ] || { echo "$(1): no available iPhone simulator. Run 'xcrun simctl list devices available', install one in Xcode > Settings > Platforms, or set SIMULATOR='iPhone 17'" >&2; exit 1; }; \
echo "$(1): simulator $$sim"
endef

.PHONY: help setup paths env generate dev build check check-file fix test test-ui lint format format-check doctor clean

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-14s %s\n", $$1, $$2}'

setup: ## Install tools (brew) and git hooks
	@if command -v brew >/dev/null; then brew install xcodegen swiftlint swiftformat fastlane; \
	else echo "brew missing: install xcodegen, swiftlint, swiftformat and fastlane by hand (Linux: only swiftformat and swiftlint apply; CI uses their docker images)"; fi
	bash .githooks/install.sh
	@$(MAKE) --no-print-directory paths
	@echo "setup done"

paths: ## Rename paths still carrying scaffold placeholders (brg-scaffold fills file contents only)
	@for d in Packages/*/; do d=$${d%/}; [ "$$d" = "$(KIT)" ] && continue; [ -f "$$d/Package.swift" ] && [ ! -e "$(KIT)" ] && mv "$$d" "$(KIT)" && echo "paths: $$d -> $(KIT)"; done; true
	@for f in App/__*App.swift; do [ -f "$$f" ] && mv "$$f" "App/$(APP)App.swift" && echo "paths: $$f -> App/$(APP)App.swift"; done; true

env: ## Write Config/Local.xcconfig from .env (API_BASE_URL and friends)
	@if [ -f .env ]; then \
	  { echo "// generated from .env by make env; do not commit"; \
	    grep -E '^[A-Z_]+=' .env | sed -E 's#^([A-Z_]+)=(.*)$$#\1 = \2#; s#//#/$$()/#g'; } > Config/Local.xcconfig; \
	  echo "env: Config/Local.xcconfig written ($$(grep -c ' = ' Config/Local.xcconfig) keys)"; \
	else echo "env: no .env (cp .env.example .env), Config/Debug.xcconfig defaults apply"; fi

generate: paths env ## Generate $(PROJECT) and App/Info.plist from project.yml (xcodegen)
	@command -v xcodegen >/dev/null || { echo "generate: xcodegen missing (make setup)" >&2; exit 1; }
	xcodegen generate --spec project.yml --use-cache
	@echo "generate: $(PROJECT) written"

dev: generate ## Open the generated project in Xcode
	open $(PROJECT)

build: ## Build the app for the simulator (needs Xcode)
	@command -v xcodebuild >/dev/null || $(call skip,build,xcodebuild); \
	[ -d $(PROJECT) ] || $(MAKE) --no-print-directory generate; \
	set -o pipefail; xcodebuild build -project $(PROJECT) -scheme $(SCHEME) -destination 'generic/platform=iOS Simulator' \
	  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO -quiet 2>&1 | tail -40 && \
	{ [ -d $(SIM_APP) ] || { echo "build: $(SIM_APP) missing" >&2; exit 1; }; } && \
	echo "build: 1 scheme checked ($(SCHEME), simulator, $(SIM_APP))"

format: ## swiftformat in place
	swiftformat $(SWIFT_DIRS)

format-check: paths ## Fail if any file is unformatted
	@n=$$(find $(SWIFT_DIRS) -name '*.swift' 2>/dev/null | wc -l | tr -d ' '); [ "$$n" -gt 0 ] || { echo "format-check: 0 swift files, nothing checked" >&2; exit 1; }; \
	command -v swiftformat >/dev/null || $(call skip,format-check,swiftformat); \
	swiftformat --lint --config .swiftformat $(SWIFT_DIRS) && echo "format-check: $$n files checked"

lint: paths ## swiftlint strict
	@n=$$(find $(SWIFT_DIRS) -name '*.swift' 2>/dev/null | wc -l | tr -d ' '); [ "$$n" -gt 0 ] || { echo "lint: 0 swift files, nothing checked" >&2; exit 1; }; \
	command -v swiftlint >/dev/null || $(call skip,lint,swiftlint); \
	swiftlint lint --strict --quiet && echo "lint: $$n files checked"

test: paths ## Package tests with swift test (Linux and macOS, no Xcode needed)
	@n=$$(find $(KIT)/Tests -name '*.swift' 2>/dev/null | wc -l | tr -d ' '); [ "$$n" -gt 0 ] || { echo "test: 0 test files, nothing checked" >&2; exit 1; }; \
	command -v swift >/dev/null || $(call skip,test,swift); \
	out=$$(cd $(KIT) && swift test 2>&1); rc=$$?; printf '%s\n' "$$out" | grep -E 'error:|warning:|failed|Executed' | tail -40; \
	[ $$rc -eq 0 ] || { printf '%s\n' "$$out" | tail -60; echo "test: FAILED" >&2; exit $$rc; }; \
	t=$$(printf '%s\n' "$$out" | grep -Eo 'Executed [0-9]+ tests?' | tail -1 | grep -Eo '[0-9]+'); \
	[ "$${t:-0}" -gt 0 ] || { echo "test: 0 tests ran" >&2; exit 1; }; echo "test: $$t tests in $$n files checked"

test-ui: ## xcodebuild test on a simulator (macOS only; not part of check), result bundle in build/
	@command -v xcodebuild >/dev/null || { echo "test-ui: xcodebuild missing (macOS only)" >&2; exit 1; }
	@[ -d $(PROJECT) ] || $(MAKE) --no-print-directory generate
	@$(call resolve_simulator,test-ui); \
	rm -rf build/TestResults.xcresult; \
	set -o pipefail; xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination "platform=iOS Simulator,name=$$sim" \
	  -derivedDataPath build/DerivedData -resultBundlePath build/TestResults.xcresult CODE_SIGNING_ALLOWED=NO -quiet 2>&1 | tail -60; \
	[ -d build/TestResults.xcresult ] || { echo "test-ui: no result bundle" >&2; exit 1; }; echo "test-ui: 1 result bundle checked (build/TestResults.xcresult)"

check: ## The gate: every gate in GATES, then the tally. CI runs exactly this.
	@mkdir -p $(STATE); rm -f $(SKIPPED) $(STATE)/.check-passed
	@for g in $(GATES); do $(MAKE) --no-print-directory $$g || { echo "check: $$g failed" >&2; exit 1; }; done
	@s=$$(cut -d' ' -f1 $(SKIPPED) 2>/dev/null | sort -u | wc -l | tr -d ' '); r=$$(( $(words $(GATES)) - s )); \
	echo "check: $$r gates run, $$s skipped"; \
	if [ "$$s" -eq 0 ]; then touch $(STATE)/.check-passed; echo "check: passed"; \
	elif [ "$${BEARING_ALLOW_SKIP:-0}" = "1" ] && [ -z "$$CI" ]; then sed 's/^/  skipped: /' $(SKIPPED); echo "check: passed with skips (BEARING_ALLOW_SKIP=1 is a local convenience; CI never sets it)"; \
	else sed 's/^/  skipped: /' $(SKIPPED); echo "check: FAILED, $$s gate(s) skipped; run make setup (Xcode for build), or BEARING_ALLOW_SKIP=1 make check locally" >&2; exit 1; fi

check-file: ## Lint one edited file, FILE=path (the Bearing edit hook runs this)
	@[ -n "$(FILE)" ] || { echo "check-file: FILE is empty, nothing checked" >&2; exit 1; }; \
	[ -f "$(FILE)" ] || { echo "check-file: $(FILE) does not exist, nothing checked" >&2; exit 1; }; \
	case "$(FILE)" in \
	  *.swift) command -v swiftlint >/dev/null || { echo "check-file: swiftlint not installed, $(FILE) not checked"; exit 0; }; swiftlint lint --strict --quiet "$(FILE)" || exit 1;; \
	  *) echo "check-file: no per-file check for $(FILE)"; exit 0;; \
	esac; \
	echo "check-file: 1 file checked"

fix: ## Apply every automatic fix
	@command -v swiftformat >/dev/null && swiftformat $(SWIFT_DIRS) || echo "fix: swiftformat missing"
	@command -v swiftlint >/dev/null && swiftlint lint --fix --quiet || echo "fix: swiftlint missing"

doctor: ## Environment diagnostics
	@echo "swift:       $$(command -v swift >/dev/null && swift --version 2>&1 | head -1 || echo missing)"
	@echo "xcodebuild:  $$(command -v xcodebuild >/dev/null && xcodebuild -version | tr '\n' ' ' || echo 'missing (macOS only)') (expected $$(cat .xcode-version 2>/dev/null || echo '?'), .xcode-version)"
	@echo "xcodegen:    $$(command -v xcodegen >/dev/null && xcodegen version || echo missing)"
	@echo "swiftlint:   $$(command -v swiftlint >/dev/null && swiftlint version || echo missing)"
	@echo "swiftformat: $$(command -v swiftformat >/dev/null && swiftformat --version || echo missing)"
	@echo "fastlane:    $$(command -v fastlane >/dev/null && fastlane --version 2>/dev/null | tail -1 || echo missing)"
	@echo "simulators:  $$(command -v xcrun >/dev/null && xcrun simctl list devices available 2>/dev/null | grep -c iPhone || echo 0) iPhone(s)$$([ -n "$(SIMULATOR)" ] && echo ", SIMULATOR=$(SIMULATOR)")"
	@echo "project:     $$([ -d $(PROJECT) ] && echo present || echo 'not generated (make generate)')"
	@echo "hooksPath:   $$(git config core.hooksPath || echo 'NOT SET (run make setup)')"

# App/Info.plist is generated by make generate next to the project and is
# git-ignored. clean leaves it alone: generate rewrites it, and deleting it
# while the project exists produced a project that no longer built.
clean: ## Remove build output (the project is regenerated by make generate)
	rm -rf build $(KIT)/.build $(PROJECT) $(STATE)/.check-passed $(SKIPPED)
