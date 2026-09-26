.PHONY: check lint test

check: lint test
	@echo "check: passed"

lint:
	python3 -m compileall -q src vendor tests

test:
	pytest -q
