.PHONY: check lint test test-integration

check: lint test

lint:
	ruff check src tests

test:
	pytest -q -m "not integration"

test-integration:
	pytest -q -m integration
