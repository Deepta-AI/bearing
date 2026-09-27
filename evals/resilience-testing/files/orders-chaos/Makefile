.PHONY: check test vet run release

check: vet test ## vet and unit tests

vet:
	go vet ./...

test:
	go test ./...

run:
	docker compose up --build

# The release build links the Postgres driver (build tag release).
release:
	go build -tags release -o bin/orders-api ./cmd/api
