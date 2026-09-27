.PHONY: test check db-seed db-reset
SEED_ROWS ?= 25

test: ## Unit tests
	python3 -m unittest discover -s tests

check: test ## The gate
	@echo "check: passed"

db-seed: ## Load SEED_ROWS demo rows into LEDGER_DB
	SEED_ROWS=$(SEED_ROWS) python3 scripts/seed_db.py

db-reset: ## Delete the local ledger file
	rm -f "$${LEDGER_DB:-ledger.jsonl}"
