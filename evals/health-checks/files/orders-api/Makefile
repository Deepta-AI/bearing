GIT_SHA ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo dev)
export GOTOOLCHAIN = local

.PHONY: check build image

check:
	go vet ./...
	go test ./...

build:
	go build -tags pgx -ldflags "-X main.version=$(GIT_SHA)" -o bin/orders-api ./cmd/api

image:
	docker build --build-arg GIT_SHA=$(GIT_SHA) -t registry.example.com/shop/orders-api:$(GIT_SHA) .
