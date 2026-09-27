export GOTOOLCHAIN = local

.PHONY: check test smoke

check:
	go vet ./...
	go test ./...

test: check

smoke:
	./scripts/smoke.sh
