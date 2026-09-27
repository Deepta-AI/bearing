.PHONY: setup vet test check fix

setup: ## Point git at the committed hooks (once per clone)
	bash .githooks/install.sh

vet: ## go vet
	go vet ./...

test: ## Unit tests
	go test ./...

check: vet test ## The gate CI runs
	@echo "check: passed"

fix: ## Format every Go file
	gofmt -w .
