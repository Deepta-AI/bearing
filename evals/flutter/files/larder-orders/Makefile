.PHONY: help setup gen dev check fix

help: ## List targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  %-8s %s\n", $$1, $$2}'

setup: ## Fetch packages and generate code
	flutter pub get
	$(MAKE) gen

gen: ## freezed, json_serializable and l10n code
	dart run build_runner build --delete-conflicting-outputs
	flutter gen-l10n

dev: ## Run against the dev API
	flutter run --dart-define-from-file=config/dev.json

check: ## Format check, analyzer, tests
	dart format --output=none --set-exit-if-changed lib test
	flutter analyze --fatal-infos
	flutter test

fix: ## Format and apply fixes
	dart format lib test
	dart fix --apply
