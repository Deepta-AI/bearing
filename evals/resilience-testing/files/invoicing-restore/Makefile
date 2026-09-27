.PHONY: check vet test lint-scripts

check: vet test lint-scripts ## vet, unit tests, shell syntax

vet:
	go vet ./...

test:
	go test ./...

lint-scripts:
	@n=0; for f in scripts/*.sh; do bash -n "$$f" || exit 1; n=$$((n+1)); done; \
	[ $$n -gt 0 ] || { echo "lint-scripts: 0 scripts"; exit 1; }; echo "lint-scripts: $$n scripts"
