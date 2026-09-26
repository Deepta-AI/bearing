.PHONY: test alerts
test:
	uv run --offline --with pytest pytest -q
alerts:
	python3 -m alerts.rules data/orders_hourly.csv
