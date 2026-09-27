.PHONY: check bench run

check:
	go vet ./...
	go test ./...

bench:
	go test -run '^$$' -bench . -benchmem ./internal/report

run:
	go run ./cmd/api
