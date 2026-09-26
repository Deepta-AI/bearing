.PHONY: check lint test run

check: lint test
	@echo "check: passed"

lint:
	python3 -m compileall -q src tests

test:
	pytest -q

run:
	PYTHONPATH=src python3 -m payouts.server
