.PHONY: help check dev migrate

help:
	@echo "check    run every test (node --test)"
	@echo "dev      run the server on :8080 against ./billing.db"
	@echo "migrate  apply pending migrations to BILLING_DB (the release job runs this)"

check:
	node --no-warnings --test 'test/**/*.test.ts'

dev:
	BILLING_DB=billing.db node --no-warnings src/server.ts

migrate:
	node --no-warnings scripts/migrate.ts
