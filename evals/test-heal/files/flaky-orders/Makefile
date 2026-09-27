.PHONY: check vet test

# CI runs `make check` through scripts/ci-test.sh.
check: vet test

vet:
	go vet ./...

# Shuffled on purpose: tests must not depend on each other's order.
test:
	go test -shuffle=on -count=1 ./...
