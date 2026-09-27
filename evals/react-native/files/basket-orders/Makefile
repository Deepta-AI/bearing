.PHONY: dev check typecheck lint test

dev:
	pnpm exec expo start

# Needs node_modules: run `pnpm install` first.
check: typecheck lint test

typecheck:
	@[ -d node_modules ] || { echo "typecheck: node_modules missing, run pnpm install" >&2; exit 1; }
	pnpm exec tsc --noEmit

lint:
	@[ -d node_modules ] || { echo "lint: node_modules missing, run pnpm install" >&2; exit 1; }
	pnpm exec eslint . --max-warnings 0

test:
	@[ -d node_modules ] || { echo "test: node_modules missing, run pnpm install" >&2; exit 1; }
	pnpm exec jest --ci
