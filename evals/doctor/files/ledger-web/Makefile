.PHONY: help setup dev test lint check

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-8s %s\n", $$1, $$2}'

setup: ## Point git at the committed hooks (once per clone)
	bash .githooks/install.sh

dev: ## Run the API locally (needs DATABASE_URL)
	node src/server.js

test: ## Unit tests
	node --no-warnings --test

lint: ## Syntax check every source file
	@n=0; for f in src/*.js test/*.js; do node --check "$$f" || exit 1; n=$$((n+1)); done; \
	[ "$$n" -gt 0 ] || { echo "lint: 0 files, nothing checked" >&2; exit 1; }; echo "lint: $$n files"

check: lint test ## The gate CI runs
