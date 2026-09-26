.PHONY: check run-api run-worker deploy rollback queue-stats replay-dlq purge-pending

TAG ?=
PREV_TAG ?=

check: ## Run the tests
	pytest -q -p no:cacheprovider tests

run-api:
	DATABASE_URL=sqlite:///payhook.db python3 -m app.server

run-worker:
	DATABASE_URL=sqlite:///payhook.db python3 -m app.worker

deploy: ## Deploy a release tag to the payments namespace
	@test -n "$(TAG)" || { echo "usage: make deploy TAG=<release tag>"; exit 1; }
	kubectl -n payments set image deploy/payhook-api api=registry.example/payhook:$(TAG)
	kubectl -n payments set image deploy/payhook-worker worker=registry.example/payhook:$(TAG)

rollback: ## Redeploy the previous release tag
	@test -n "$(PREV_TAG)" || { echo "usage: make rollback PREV_TAG=<tag>"; exit 1; }
	$(MAKE) deploy TAG=$(PREV_TAG)

queue-stats: ## Queue depth, oldest pending age, dead letters by error
	kubectl -n payments exec deploy/payhook-worker -- python3 scripts/queue_stats.py --by-error

replay-dlq: ## Move every dead event back to pending
	kubectl -n payments exec deploy/payhook-worker -- python3 scripts/replay_dead.py

purge-pending: ## Delete every pending event (staging resets only)
	kubectl -n payments exec deploy/payhook-worker -- python3 scripts/purge_pending.py --yes
