.PHONY: check lint-migrations test migrate migrate-down

check: lint-migrations test

lint-migrations:
	python3 scripts/check_migrations.py db/migrations

test:
	pytest -q -p no:cacheprovider

migrate:
	goose -dir db/migrations postgres "$$DATABASE_URL" up

migrate-down:
	goose -dir db/migrations postgres "$$DATABASE_URL" down
