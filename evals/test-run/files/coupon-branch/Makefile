.PHONY: check lint test test-integration

check: lint test
	@echo "check: passed"

lint:
	python3 -m compileall -q src tests

test:
	pytest -q -m "not integration"

test-integration:
	pytest -q -m integration tests/integration
