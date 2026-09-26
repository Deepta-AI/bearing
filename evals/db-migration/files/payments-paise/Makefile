# Ledger: payments for the shop, on SQLite. Migrations are goose SQL files.
DB_PATH ?= /srv/ledger/ledger.db
GOOSE ?= goose

.PHONY: check test migrate migrate-status

check: test

test:
	pytest -q

migrate:
	$(GOOSE) -dir db/migrations sqlite3 "$(DB_PATH)" up

migrate-status:
	$(GOOSE) -dir db/migrations sqlite3 "$(DB_PATH)" status
