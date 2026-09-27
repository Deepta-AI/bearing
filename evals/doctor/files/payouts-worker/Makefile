.PHONY: help setup test lint check

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-8s %s\n", $$1, $$2}'

setup: ## Once per clone: point git at the committed hooks
	-bash scripts/install-hooks.sh
	@echo "setup done: git hooks installed"

test: ## Unit tests
	pytest -q -p no:cacheprovider

lint: ## Byte-compile every module
	python3 -m compileall -q src tests

check: lint test ## The gate CI runs
