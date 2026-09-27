.PHONY: help setup check migrate migrate-new

help:
	@echo "setup        pnpm install --frozen-lockfile"
	@echo "check        prettier, eslint, tsc, vitest"
	@echo "migrate      apply drizzle/ to DATABASE_URL (release job only)"
	@echo "migrate-new  name=<name>: generate a migration from src/db/schema.ts"

setup:
	pnpm install --frozen-lockfile

check:
	pnpm exec prettier --check .
	pnpm exec eslint . --max-warnings 0
	pnpm exec tsc --noEmit
	pnpm exec vitest run

migrate:
	pnpm exec drizzle-kit migrate

migrate-new:
	pnpm exec drizzle-kit generate --name $(name)
