.PHONY: dev test check
dev: ## Run the API locally on $$PORT
	go run ./cmd/api

test: ## Unit tests
	go test ./...

check: test ## The gate
	@echo "check: passed"
