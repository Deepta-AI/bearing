.PHONY: help check fmt-check vet test build

help: ## List targets
	@grep -E '^[a-z-]+:.*## ' Makefile | sed 's/:.*## /: /'

check: fmt-check vet test ## Every gate CI runs

fmt-check: ## Fail on unformatted files
	@files=$$(gofmt -l .); [ -z "$$files" ] || { echo "unformatted: $$files"; exit 1; }; \
	echo "fmt-check: $$(find . -name '*.go' | wc -l | tr -d ' ') files checked"

vet: ## go vet
	go vet ./...

test: ## Unit tests
	go test -count=1 ./...

build: ## Build bin/api
	CGO_ENABLED=0 go build -o bin/api ./cmd/api
