GO ?= go
export GOTOOLCHAIN=local
export GOFLAGS=-mod=vendor

.PHONY: check build test vet

check: vet test build

vet:
	$(GO) vet ./...

test:
	$(GO) test ./...

build:
	CGO_ENABLED=0 $(GO) build -trimpath -o bin/fleet-agent ./cmd/fleet-agent
