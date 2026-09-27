.PHONY: check vet test sql-lint cover build

COVER_MIN ?= 10

check: vet test sql-lint cover

vet:
	go vet ./...

test:
	go test ./...

sql-lint:
	@bash scripts/sql_lint.sh

cover:
	@go test -coverprofile=cover.out ./internal/... > /dev/null
	@total=$$(go tool cover -func=cover.out | awk '/^total:/ {print int($$3)}'); \
	if [ "$$total" -lt "$(COVER_MIN)" ]; then \
		echo "coverage $$total% is below $(COVER_MIN)%"; exit 1; \
	else \
		echo "coverage ok"; \
	fi

build:
	go build -o orders ./cmd/orders
