.PHONY: check build run

check:
	go vet ./...
	go test ./...

build:
	go build -o bin/shipments-api ./cmd/server

run:
	go run ./cmd/server
