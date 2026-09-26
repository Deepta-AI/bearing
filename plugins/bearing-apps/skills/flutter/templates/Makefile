# __REPO_NAME__ (Flutter app). Every command lives here. `make help` lists them.
SHELL := /bin/bash
.DEFAULT_GOAL := help
FLUTTER ?= flutter
DART ?= dart
# Flavour file under config/ for dev, build-android and build-ios.
FLAVOR ?= dev
STATE := .bearing/state
SKIPPED := $(STATE)/.skipped
# The gates `make check` runs, in order. test-integration needs a device
# and the builds need minutes and signing, so they are manual targets and
# CI jobs, not part of check.
GATES := format-check analyze test
DART_DIRS := lib test integration_test
# Files each gate looks at: tracked plus untracked, minus ignored and generated.
DART_FILES = $$(git ls-files -co --exclude-standard -- 'lib/*.dart' 'test/*.dart' 'integration_test/*.dart' | grep -Ev '\.(g|freezed)\.dart$$|^lib/l10n/generated/' || true)
TEST_FILES = $$(git ls-files -co --exclude-standard -- 'test/*_test.dart')
INTEGRATION_FILES = $$(git ls-files -co --exclude-standard -- 'integration_test/*_test.dart')

# $(call skip,gate,tool): the tool is absent. Print it, record it, and let the
# other gates run; `check` fails on any recorded skip. Never a silent pass.
define skip
{ mkdir -p $(STATE); echo "$(1): SKIPPED ($(2) not installed)"; echo "$(1) $(2)" >> $(SKIPPED); exit 0; }
endef

.PHONY: help setup gen dev check check-file fix format format-check analyze test test-integration build-android build-ios release-android release-ios vuln doctor clean

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-16s %s\n", $$1, $$2}'

setup: ## Install packages (writes pubspec.lock), platform folders, generated code and git hooks
	$(FLUTTER) pub get
	@if [ ! -d android/app ] || [ ! -d ios/Runner ]; then \
	  echo "setup: creating the platform folders with flutter create (org __ORG_ID__)"; \
	  $(FLUTTER) create --empty --platforms=android,ios --org __ORG_ID__ --project-name app . >/dev/null; \
	  grep -lq 'MyApp' test/widget_test.dart 2>/dev/null && rm -f test/widget_test.dart; \
	  echo "setup: commit android/ and ios/; fastlane files were kept"; fi
	$(MAKE) --no-print-directory gen
	bash .githooks/install.sh
	@echo "setup done"

gen: ## Generate localisations, freezed and json code
	$(FLUTTER) gen-l10n
	$(DART) run build_runner build
	@echo "gen: $$(git ls-files -co --exclude-standard --ignored -- '*.g.dart' '*.freezed.dart' 'lib/l10n/generated/*.dart' | wc -l | tr -d ' ') generated files"

dev: ## Run on the connected device or emulator with config/$(FLAVOR).json
	$(FLUTTER) run --dart-define-from-file=config/$(FLAVOR).json

format: ## dart format
	$(DART) format $(DART_DIRS)

format-check: ## Fail if any Dart file is unformatted
	@n=$$(echo "$(DART_FILES)" | grep -c . || true); \
	[ "$$n" -gt 0 ] || { echo "format-check: 0 dart files, nothing checked" >&2; exit 1; }; \
	command -v $(DART) >/dev/null || $(call skip,format-check,dart); \
	$(DART) format --output=none --set-exit-if-changed $(DART_DIRS) || { echo "format-check: run make fix" >&2; exit 1; }; \
	echo "format-check: $$n files checked"

analyze: ## flutter analyze with infos fatal (needs make setup for the generated code)
	@n=$$(echo "$(DART_FILES)" | grep -c . || true); \
	[ "$$n" -gt 0 ] || { echo "analyze: 0 dart files, nothing checked" >&2; exit 1; }; \
	command -v $(FLUTTER) >/dev/null || $(call skip,analyze,flutter); \
	[ -d .dart_tool ] || { echo "analyze: packages not resolved; run make setup" >&2; exit 1; }; \
	$(FLUTTER) analyze --fatal-infos && echo "analyze: $$n files checked"

test: ## Unit and widget tests with coverage (coverage/lcov.info)
	@n=$$(echo "$(TEST_FILES)" | grep -c . || true); \
	[ "$$n" -gt 0 ] || { echo "test: 0 test files, nothing checked" >&2; exit 1; }; \
	command -v $(FLUTTER) >/dev/null || $(call skip,test,flutter); \
	$(FLUTTER) test --coverage && echo "test: $$n test files checked"

test-integration: ## integration_test on a device, emulator or desktop (DEVICE=<id>); not part of check
	@n=$$(echo "$(INTEGRATION_FILES)" | grep -c . || true); \
	[ "$$n" -gt 0 ] || { echo "test-integration: 0 test files, nothing checked" >&2; exit 1; }; \
	command -v $(FLUTTER) >/dev/null || $(call skip,test-integration,flutter); \
	$(FLUTTER) test integration_test $(if $(DEVICE),-d $(DEVICE),) && echo "test-integration: $$n test files checked"

build-android: ## Release APK from config/$(FLAVOR).json (BUILD_NUMBER from CI or 1)
	$(FLUTTER) build apk --release --dart-define-from-file=config/$(FLAVOR).json --build-number=$${BUILD_NUMBER:-1}
	@echo "build-android: $$(ls build/app/outputs/flutter-apk/*.apk | wc -l | tr -d ' ') apk built"

build-ios: ## Release IPA from config/$(FLAVOR).json (macOS with Xcode only)
	@[ "$$(uname)" = Darwin ] || { echo "build-ios: needs macOS with Xcode; Linux CI builds Android only" >&2; exit 1; }
	$(FLUTTER) build ipa --release --dart-define-from-file=config/$(FLAVOR).json --build-number=$${BUILD_NUMBER:-1}
	@echo "build-ios: $$(ls build/ios/ipa/*.ipa | wc -l | tr -d ' ') ipa built"

release-android: ## Print the Play Store lane; a person runs it
	@echo "release-android: run it yourself, after the release checklist:"
	@echo "  cd android && BUILD_NUMBER=<n> SUPPLY_JSON_KEY=<path outside the repo> bundle exec fastlane internal"

release-ios: ## Print the TestFlight lane; a person runs it on macOS
	@echo "release-ios: run it yourself on macOS, after the release checklist:"
	@echo "  cd ios && BUILD_NUMBER=<n> bundle exec fastlane beta"

vuln: ## osv-scanner over pubspec.lock (a CI job, not part of check)
	@command -v osv-scanner >/dev/null || $(call skip,vuln,osv-scanner); \
	[ -f pubspec.lock ] || { echo "vuln: no pubspec.lock; run make setup and commit it" >&2; exit 1; }; \
	n=$$(grep -cE '^  [a-z0-9_]+:$$' pubspec.lock || true); \
	[ "$$n" -gt 0 ] || { echo "vuln: 0 packages in pubspec.lock" >&2; exit 1; }; \
	osv-scanner scan --lockfile=pubspec.lock && echo "vuln: $$n packages checked"

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
	  *.dart) command -v $(DART) >/dev/null || { echo "check-file: dart not installed, $(FILE) not checked"; exit 0; }; $(DART) analyze --fatal-infos "$(FILE)" || exit 1;; \
	  *) echo "check-file: no per-file check for $(FILE)"; exit 0;; \
	esac; \
	echo "check-file: 1 file checked"

fix: format ## Apply every automatic fix
	@$(DART) fix --apply || true

doctor: ## Environment diagnostics
	@echo "flutter:    $$(command -v $(FLUTTER) >/dev/null && $(FLUTTER) --version 2>/dev/null | head -1 || echo missing)"
	@echo "dart:       $$(command -v $(DART) >/dev/null && $(DART) --version 2>&1 | head -1 || echo missing)"
	@echo "packages:   $$([ -d .dart_tool ] && echo resolved || echo 'NOT RESOLVED (run make setup)')"
	@echo "lockfile:   $$([ -f pubspec.lock ] && echo present || echo 'MISSING (run make setup and commit pubspec.lock)')"
	@echo "generated:  $$(ls lib/l10n/generated/app_localizations.dart lib/features/health/health.g.dart 2>/dev/null | wc -l | tr -d ' ')/2 files (run make gen)"
	@echo "android:    $$([ -d android/app ] && echo present || echo 'missing (run make setup)')"
	@echo "ios:        $$([ -d ios/Runner ] && echo present || echo 'missing (run make setup)')"
	@echo "osv:        $$(command -v osv-scanner >/dev/null && osv-scanner --version 2>/dev/null | head -1 || echo missing)"
	@echo "hooksPath:  $$(git config core.hooksPath || echo 'NOT SET (run make setup)')"
	@command -v $(FLUTTER) >/dev/null && $(FLUTTER) doctor || true

clean: ## Remove build output, coverage and generated code
	@command -v $(FLUTTER) >/dev/null && $(FLUTTER) clean >/dev/null || true
	rm -rf build coverage $(STATE)/.check-passed $(SKIPPED)
