.PHONY: check fmt test vet build

check: fmt vet test
	@echo "check: passed"

fmt:
	@out=$$(gofmt -l .); if [ -n "$$out" ]; then echo "gofmt needed:"; echo "$$out"; exit 1; fi

vet:
	go vet ./...

test:
	go test ./...

build:
	go build -o billingd ./cmd/billingd
