.PHONY: check run

check:
	GOTOOLCHAIN=local go vet ./...
	GOTOOLCHAIN=local go test ./...

run:
	GOTOOLCHAIN=local go run ./cmd/kiosk
