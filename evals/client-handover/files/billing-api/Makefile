IMAGE ?= registry.example.com/riverton/billing-api

.PHONY: run check image deploy

run:
	uvicorn app.main:app --reload

check:
	pytest -q -p no:cacheprovider tests

image:
	docker build -t $(IMAGE):latest .

deploy:
	kubectl --namespace billing apply -f k8s/
