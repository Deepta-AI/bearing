.PHONY: check test vet run

check: vet test

vet:
	GOTOOLCHAIN=local go vet ./...

test:
	GOTOOLCHAIN=local go test ./...

run:
	GOTOOLCHAIN=local go run ./cmd/api
