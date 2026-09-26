# __REPO_NAME__ (Android app). Every command lives here. `make help` lists them.
SHELL := /bin/bash
.DEFAULT_GOAL := help
GRADLEW := ./gradlew
GRADLE_FLAGS ?= --console=plain
MODULE := app
STATE := .bearing/state
SKIPPED := $(STATE)/.skipped
# The gates `make check` runs, in order. test-ui needs a device or emulator,
# so it is a CI job on a device runner and a manual target, not part of check.
GATES := ktlint detekt lint test build
APK := $(MODULE)/build/outputs/apk/debug/$(MODULE)-debug.apk
UNIT_REPORTS := $(MODULE)/build/test-results/testDebugUnitTest
LINT_REPORT := $(MODULE)/build/reports/lint-results-debug.xml
WRAPPER_JAR := gradle/wrapper/gradle-wrapper.jar
# The Gradle version the committed wrapper runs, read from its properties.
GRADLE_VERSION := $(shell sed -n 's|.*/gradle-\([0-9.]*\)-.*|\1|p' gradle/wrapper/gradle-wrapper.properties 2>/dev/null || echo 9.7.1)

# $(call skip,gate,tool): the tool is absent. Print it, record it, and let the
# other gates run; `check` fails on any recorded skip. Never a silent pass.
define skip
{ mkdir -p $(STATE); echo "$(1): SKIPPED ($(2) not installed)"; echo "$(1) $(2)" >> $(SKIPPED); exit 0; }
endef
# Every Gradle target goes through this: the committed wrapper jar and a JDK.
define require_gradle
[ -f $(WRAPPER_JAR) ] || $(call skip,$(1),gradle-wrapper.jar); \
command -v java >/dev/null || $(call skip,$(1),java)
endef

.PHONY: help setup bootstrap dev check check-file fix test test-ui lint ktlint detekt build bundle doctor clean

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'

setup: ## Verify the wrapper, write local.properties, install git hooks
	@chmod +x gradlew 2>/dev/null || true
	@[ -f $(WRAPPER_JAR) ] && echo "setup: wrapper jar present (gradle $(GRADLE_VERSION))" || { echo "setup: $(WRAPPER_JAR) missing; run make bootstrap" >&2; exit 1; }
	@command -v java >/dev/null && echo "setup: $$(java -version 2>&1 | head -1)" || echo "setup: no JDK on PATH; install JDK 17 (Android Studio bundles one)"
	@if [ ! -f local.properties ] && [ -n "$$ANDROID_HOME" ]; then echo "sdk.dir=$$ANDROID_HOME" > local.properties; echo "setup: local.properties written from ANDROID_HOME"; fi
	@echo "setup: ktlint and detekt run through the Gradle plugins; nothing to install"
	bash .githooks/install.sh
	@echo "setup done"

# The wrapper jar ships committed. This target refreshes it after a bump of
# distributionUrl in gradle-wrapper.properties: it fetches the jar Gradle
# itself commits for that release and verifies it against the sha256 Gradle
# publishes at services.gradle.org. Needs curl and network. Commit the result.
bootstrap: ## Download and verify gradle-wrapper.jar for the version in gradle-wrapper.properties
	@command -v curl >/dev/null || { echo "bootstrap: curl missing" >&2; exit 1; }
	@v="$(GRADLE_VERSION)"; tag="v$$v"; case "$$v" in *.*.*) ;; *) tag="v$$v.0";; esac; \
	echo "bootstrap: fetching gradle-wrapper.jar for gradle $$v"; \
	curl -fsSL -o $(WRAPPER_JAR).tmp "https://raw.githubusercontent.com/gradle/gradle/$$tag/gradle/wrapper/gradle-wrapper.jar" || { echo "bootstrap: download failed" >&2; rm -f $(WRAPPER_JAR).tmp; exit 1; }; \
	want=$$(curl -fsSL "https://services.gradle.org/distributions/gradle-$$v-wrapper.jar.sha256") || { echo "bootstrap: checksum download failed" >&2; rm -f $(WRAPPER_JAR).tmp; exit 1; }; \
	have=$$( (command -v sha256sum >/dev/null && sha256sum $(WRAPPER_JAR).tmp || shasum -a 256 $(WRAPPER_JAR).tmp) | cut -d' ' -f1); \
	[ "$$have" = "$$want" ] || { echo "bootstrap: sha256 mismatch (got $$have, published $$want)" >&2; rm -f $(WRAPPER_JAR).tmp; exit 1; }; \
	mv $(WRAPPER_JAR).tmp $(WRAPPER_JAR); chmod +x gradlew; echo "bootstrap: $(WRAPPER_JAR) verified (1 checksum); commit it"

dev: ## Open in Android Studio (printed) and installDebug when a device is attached
	@echo "dev: open Android Studio, File > Open, choose $$(pwd)"
	@set -a; [ -f .env ] && . ./.env; set +a; \
	if command -v adb >/dev/null && [ "$$(adb devices | tail -n +2 | grep -c 'device$$')" -gt 0 ]; then \
	  $(GRADLEW) $(GRADLE_FLAGS) installDebug; \
	else echo "dev: no device attached (adb devices); start an emulator or plug a phone in, then rerun"; fi

ktlint: ## ktlint check (Android style, .editorconfig)
	@n=$$(git ls-files -co --exclude-standard '*.kt' '*.kts' | wc -l | tr -d ' '); [ "$$n" -gt 0 ] || { echo "ktlint: 0 kotlin files, nothing checked" >&2; exit 1; }; \
	$(call require_gradle,ktlint); \
	$(GRADLEW) $(GRADLE_FLAGS) ktlintCheck && echo "ktlint: $$n files checked"

detekt: ## detekt static analysis (detekt.yml)
	@n=$$(git ls-files -co --exclude-standard '*.kt' '*.kts' | wc -l | tr -d ' '); [ "$$n" -gt 0 ] || { echo "detekt: 0 kotlin files, nothing checked" >&2; exit 1; }; \
	$(call require_gradle,detekt); \
	$(GRADLEW) $(GRADLE_FLAGS) detekt && echo "detekt: $$n files checked"

lint: ## Android lint on the debug variant (lint.xml); any error fails
	@n=$$(git ls-files -co --exclude-standard '*.kt' '*.kts' '*.xml' | wc -l | tr -d ' '); [ "$$n" -gt 0 ] || { echo "lint: 0 source files, nothing checked" >&2; exit 1; }; \
	$(call require_gradle,lint); \
	$(GRADLEW) $(GRADLE_FLAGS) lintDebug; st=$$?; \
	[ -f $(LINT_REPORT) ] || { echo "lint: no report at $(LINT_REPORT) (gradle exit $$st)" >&2; exit 1; }; \
	errors=$$(grep -c 'severity="Error"' $(LINT_REPORT) || true); warnings=$$(grep -c 'severity="Warning"' $(LINT_REPORT) || true); \
	if [ "$$st" -ne 0 ] || [ "$$errors" -ne 0 ]; then echo "lint: $$errors error(s), $$warnings warning(s); see $(LINT_REPORT)" >&2; exit 1; fi; \
	echo "lint: $$n files checked, 0 errors, $$warnings warning(s)"

test: ## Unit tests (JUnit Jupiter on the JVM)
	@$(call require_gradle,test); \
	$(GRADLEW) $(GRADLE_FLAGS) testDebugUnitTest; \
	files=$$(ls $(UNIT_REPORTS)/*.xml 2>/dev/null | wc -l | tr -d ' '); [ "$$files" -gt 0 ] || { echo "test: 0 report files, no tests ran" >&2; exit 1; }; \
	total=0; for t in $$(grep -ho 'tests="[0-9]*"' $(UNIT_REPORTS)/*.xml | grep -o '[0-9]*'); do total=$$((total+t)); done; \
	[ "$$total" -gt 0 ] || { echo "test: 0 tests ran" >&2; exit 1; }; echo "test: $$total tests in $$files classes checked"

test-ui: ## Instrumented and Compose tests on the attached device or emulator (not part of check)
	@$(call require_gradle,test-ui); \
	command -v adb >/dev/null || { echo "test-ui: adb missing; install the Android SDK platform-tools" >&2; exit 1; }; \
	d=$$(adb devices | tail -n +2 | grep -c 'device$$'); [ "$$d" -gt 0 ] || { echo "test-ui: 0 devices attached (adb devices); start an emulator first" >&2; exit 1; }; \
	$(GRADLEW) $(GRADLE_FLAGS) connectedDebugAndroidTest && echo "test-ui: connected tests checked on $$d device(s)"

build: ## assembleDebug and print the APK size
	@$(call require_gradle,build); \
	$(GRADLEW) $(GRADLE_FLAGS) assembleDebug; \
	[ -f $(APK) ] || { echo "build: $(APK) missing" >&2; exit 1; }; \
	echo "build: 1 apk checked, $$(du -h $(APK) | cut -f1) at $(APK)"

bundle: ## bundleRelease (signing comes from ANDROID_KEYSTORE_* variables, see README)
	@$(call require_gradle,bundle); \
	$(GRADLEW) $(GRADLE_FLAGS) bundleRelease && echo "bundle: $$(ls $(MODULE)/build/outputs/bundle/release/*.aab | wc -l | tr -d ' ') aab written"

check: ## The gate: every gate in GATES, then the tally. CI runs exactly this.
	@mkdir -p $(STATE); rm -f $(SKIPPED) $(STATE)/.check-passed
	@for g in $(GATES); do $(MAKE) --no-print-directory $$g || { echo "check: $$g failed" >&2; exit 1; }; done
	@s=$$(cut -d' ' -f1 $(SKIPPED) 2>/dev/null | sort -u | wc -l | tr -d ' '); r=$$(( $(words $(GATES)) - s )); \
	echo "check: $$r gates run, $$s skipped"; \
	if [ "$$s" -eq 0 ]; then touch $(STATE)/.check-passed; echo "check: passed"; \
	elif [ "$${BEARING_ALLOW_SKIP:-0}" = "1" ] && [ -z "$$CI" ]; then sed 's/^/  skipped: /' $(SKIPPED); echo "check: passed with skips (BEARING_ALLOW_SKIP=1 is a local convenience; CI never sets it)"; \
	else sed 's/^/  skipped: /' $(SKIPPED); echo "check: FAILED, $$s gate(s) skipped; install JDK 17 (make doctor), or BEARING_ALLOW_SKIP=1 make check locally" >&2; exit 1; fi

check-file: ## Lint one edited file, FILE=path (the Bearing edit hook runs this)
	@[ -n "$(FILE)" ] || { echo "check-file: FILE is empty, nothing checked" >&2; exit 1; }; \
	[ -f "$(FILE)" ] || { echo "check-file: $(FILE) does not exist, nothing checked" >&2; exit 1; }; \
	case "$(FILE)" in \
	  *.kt|*.kts) command -v ktlint >/dev/null || { echo "check-file: ktlint not installed, $(FILE) not checked (make ktlint covers it)"; exit 0; }; ktlint "$(FILE)" || exit 1;; \
	  *) echo "check-file: no per-file check for $(FILE)"; exit 0;; \
	esac; \
	echo "check-file: 1 file checked"

fix: ## Apply every automatic fix (ktlintFormat)
	@$(call require_gradle,fix); $(GRADLEW) $(GRADLE_FLAGS) ktlintFormat

doctor: ## Environment diagnostics
	@echo "java:         $$(command -v java >/dev/null && java -version 2>&1 | head -1 || echo 'missing (need JDK 17)')"
	@echo "ANDROID_HOME: $${ANDROID_HOME:-NOT SET}"
	@echo "sdk.dir:      $$(grep -s '^sdk.dir=' local.properties | cut -d= -f2- | grep . || echo 'no local.properties (run make setup)')"
	@echo "wrapper jar:  $$([ -f $(WRAPPER_JAR) ] && echo present || echo 'MISSING (run make bootstrap)')"
	@echo "gradle:       $(GRADLE_VERSION) (gradle-wrapper.properties)"
	@echo "adb:          $$(command -v adb >/dev/null && adb version | head -1 || echo missing)"
	@echo "hooksPath:    $$(git config core.hooksPath || echo 'NOT SET (run make setup)')"

clean: ## Remove build output
	@[ -f $(WRAPPER_JAR) ] && command -v java >/dev/null && $(GRADLEW) $(GRADLE_FLAGS) clean || true
	rm -rf $(MODULE)/build build .gradle/configuration-cache $(STATE)/.check-passed $(SKIPPED)
