.PHONY: help install test test-integration migrate run deploy

PYTEST ?= pytest
PYTHON ?= python3

help: ## List targets
	@grep -E '^[a-z-]+:.*## ' Makefile | sed 's/:.*## /\t/'

install: ## Install the package and dev tools
	$(PYTHON) -m pip install -e '.[dev]'

test: ## Unit tests (no database)
	$(PYTEST) -q -m "not integration"

test-integration: ## Integration tests against DATABASE_URL
	$(PYTEST) -q -m integration

migrate: ## Apply migrations/*.sql to DATABASE_URL
	$(PYTHON) scripts/migrate.py

run: ## Serve on :8080
	$(PYTHON) -m ledger.server

deploy: ## Deploy the current commit to production (see docs/adr/0002-deploys.md)
	./scripts/deploy.sh production
