.PHONY: help setup fmt-check vet test check fix

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-10s %s\n", $$1, $$2}'

setup: ## One-time setup for a fresh clone
	bash scripts/install-hooks.sh

fmt-check: ## Fail if any Go file is not gofmt clean
	@out=$$(gofmt -l cmd internal); [ -z "$$out" ] || { echo "gofmt needed: $$out"; exit 1; }

vet: ## go vet
	go vet ./...

test: ## Unit tests
	go test ./...

check: fmt-check vet test ## The gate CI runs
	@echo "check: passed"

fix: ## Format everything
	gofmt -w cmd internal
