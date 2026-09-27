export GOTOOLCHAIN := local

.PHONY: check test vet run

check: vet test

vet:
	go vet ./...

test:
	go test ./...

run:
	go run ./cmd/api
