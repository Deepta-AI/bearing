.PHONY: dev test vet check

dev: ## Run the API locally with .env
	set -a; [ -f .env ] && . ./.env; set +a; go run ./cmd/api

vet:
	go vet ./...

test: ## Unit tests
	go test ./...

check: vet test ## The gate
	@echo "check: passed"
