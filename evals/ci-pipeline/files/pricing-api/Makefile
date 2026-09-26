.PHONY: help check lint test build run

help: ## List targets
	@grep -E '^[a-z-]+:.*## ' Makefile | sed 's/:.*## /\t/'

check: lint test ## The gates CI runs

lint: ## go vet and gofmt
	go vet ./...
	@out="$$(gofmt -l .)"; if [ -n "$$out" ]; then echo "gofmt needed:"; echo "$$out"; exit 1; fi

test: ## Tests with coverage; the output is kept for the CI log artifact
	go test -race -coverprofile=coverage.out ./... 2>&1 | tee test-output.txt

build: ## bin/pricing-api
	CGO_ENABLED=0 go build -o bin/pricing-api ./cmd/api

run: ## Serve on :8080
	go run ./cmd/api
