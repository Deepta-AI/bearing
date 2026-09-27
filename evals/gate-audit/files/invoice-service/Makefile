.PHONY: check lint test schema migrations

check: lint test schema migrations

lint:
	@find src -name '*.py' | xargs -r python3 -m py_compile && echo "lint ok"

test:
	@pytest -q tests || [ $$? -eq 5 ]

schema:
	@mkdir -p build
	@python3 scripts/gen_schema.py fixtures/events.json > build/schema.json
	@python3 scripts/validate_events.py build/schema.json fixtures/events.json

migrations:
	@bash scripts/check_migrations.sh
