.PHONY: check lint test

check: lint test ## Every gate CI runs

lint: ## ruff
	ruff check --no-cache src tests

test: ## pytest
	pytest -q -p no:cacheprovider
