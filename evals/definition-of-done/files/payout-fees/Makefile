.PHONY: lint test check

lint: ## House lint over src/
	python3 scripts/lint.py src

test: ## Unit tests
	pytest -q

check: lint test ## The gate
	@echo "check: passed"
