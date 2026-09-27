.PHONY: help check clone

help: ## List targets
	@grep -E '^[a-z-]+:.*## ' Makefile | sed 's/:.*## /: /'

check: ## Validate repos.yaml
	python3 scripts/check_manifest.py repos.yaml

clone: ## Clone every active repository in repos.yaml that is not here yet
	python3 scripts/check_manifest.py --clone repos.yaml
