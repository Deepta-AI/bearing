.PHONY: help check dbt-build backfill

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'

check: ## pytest over the DAG and the dbt layout; runs offline
	pytest -q -p no:cacheprovider tests

dbt-build: ## dbt build against the DBT_* warehouse
	cd dbt && dbt build --profiles-dir ..

# Rebuild the orders mart after a model fix.
backfill: ## Rebuild fct_orders_daily (start= end= are for the log line)
	@echo "backfill $(start) to $(end)"
	cd dbt && dbt run --profiles-dir .. --full-refresh --select fct_orders_daily
	cd dbt && dbt test --profiles-dir .. --select fct_orders_daily
