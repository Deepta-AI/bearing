.PHONY: vet test check

vet: ## go vet
	go vet ./...

test: ## Unit tests
	go test ./...

check: vet test ## The gate
	@echo "check: passed"
