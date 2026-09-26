# Billing service. Migrations are goose SQL files in db/migrations.
DATABASE_URL ?= postgres://billing_app@staging-db.internal:5432/billing?sslmode=require
GOOSE ?= goose

.PHONY: check test vet migrate migrate-status

check: vet test

vet:
	go vet ./...

test:
	go test ./...

migrate:
	$(GOOSE) -dir db/migrations postgres "$(DATABASE_URL)" up

migrate-status:
	$(GOOSE) -dir db/migrations postgres "$(DATABASE_URL)" status
