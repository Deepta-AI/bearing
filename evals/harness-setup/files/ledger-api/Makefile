.PHONY: help check fmt-check hooks deploy ship

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-10s %s\n", $$1, $$2}'

check: fmt-check ## The gate: formatting, vet and tests
	go vet ./...
	go test ./...

fmt-check:
	@test -z "$$(gofmt -l .)" || { gofmt -l .; echo "gofmt: files above need formatting"; exit 1; }

hooks: ## Enable the repository git hooks in this clone (run once after cloning)
	git config core.hooksPath .githooks

deploy: ## Apply the manifests to the current kube context (a person runs this)
	kubectl apply -f deploy/k8s.yaml

ship: check deploy ## The gate, then the rollout in one step (a person runs this)
