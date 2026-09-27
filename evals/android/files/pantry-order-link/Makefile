# Pantry Android. `make help` lists the targets.
GRADLEW := ./gradlew

.PHONY: help check test lint fix

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-8s %s\n", $$1, $$2}'

check: ## ktlint, detekt, Android lint, unit tests, debug build
	$(GRADLEW) ktlintCheck detekt lint testDebugUnitTest assembleDebug

test: ## Unit tests
	$(GRADLEW) testDebugUnitTest

lint: ## Android lint
	$(GRADLEW) lint

fix: ## Format with ktlint
	$(GRADLEW) ktlintFormat
