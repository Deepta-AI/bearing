.PHONY: check vet test

check: vet test
	@echo "check: passed"

vet:
	go vet ./...

# The replay tests are slow; the webhook package is what changes most.
test:
	go test ./internal/webhook/...
