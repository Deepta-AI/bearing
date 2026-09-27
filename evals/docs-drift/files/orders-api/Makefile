.PHONY: dev test check config-doc
dev: ## Run the API locally on $$PORT
	go run ./cmd/api

test: ## Unit tests
	go test ./...

check: test ## The gate
	@echo "check: passed"

config-doc: ## Regenerate docs/config.md from the code
	go run ./tools/envdoc > docs/config.md
