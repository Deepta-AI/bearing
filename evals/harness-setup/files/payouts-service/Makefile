.PHONY: help check fmt-check hooks deploy-payments

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-16s %s\n", $$1, $$2}'

check: fmt-check ## The gate: formatting, vet and tests
	go vet ./...
	go test ./...

fmt-check:
	@test -z "$$(gofmt -l .)" || { gofmt -l .; echo "gofmt: files above need formatting"; exit 1; }

hooks: ## Enable the repository git hooks in this clone (run once after cloning)
	git config core.hooksPath .githooks

deploy-payments: ## Roll out the settlement service (a person runs this)
	kubectl apply -f deploy/payments.yaml
