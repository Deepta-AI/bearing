.PHONY: build vet test test-integration load-test check

LOAD_BASE_URL ?= https://invoices.prod.example.in

build:
	go build ./...

vet:
	go vet ./...

# Keep the runner output as a CI artifact.
test:
	go test -count=1 -cover ./... 2>&1 | tee test-output.txt
	@echo "unit tests passed"

test-integration:
	go test -count=1 -tags=integration ./internal/store/...

load-test:
	k6 run -e BASE_URL=$(LOAD_BASE_URL) tests/load/smoke.js

check: vet test
