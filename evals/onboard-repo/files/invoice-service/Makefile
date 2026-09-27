.PHONY: help setup dev lint test check

help: ## List the targets
	@grep -E '^[a-z]+:.*## ' Makefile | sed 's/:.*## /\t/'

setup: ## Point git at the team hooks
	git config core.hooksPath tools/githooks

dev: ## Run the service on :8080
	node src/server.js

lint: ## Lint src/
	npm run --silent lint

test: ## Unit tests
	npm test

check: lint ## The gate
