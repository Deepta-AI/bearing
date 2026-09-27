.PHONY: check test lint dev

check: lint test

lint:
	ruff check .

test:
	pytest -q

dev:
	uvicorn app.main:create_app --factory --reload
