SHELL := /bin/bash

.PHONY: check validate lint-skills lint-tools lint-evals lint-triggers lint-prose docs docs-check test

check: validate lint-skills lint-tools lint-evals lint-triggers lint-prose docs-check test ## Every gate

validate: ## Marketplace and plugin manifests parse and share VERSION
	@python3 bin/validate-plugins.py

lint-skills: ## Names, frontmatter, 220-character description, sections, under 140 lines
	@python3 bin/lint-skills.py

lint-tools: ## allowed-tools: no shell wildcards, no publishing commands (ADR-0001)
	@python3 bin/lint-tools.py

lint-evals: ## Every skill has evals/<name>/evals.json or sits on the shrinking evals/.pending
	@python3 bin/lint-evals.py

lint-triggers: ## Every skill with evals has 3 trigger requests and 2 near misses
	@python3 bin/lint-triggers.py

lint-prose: ## No em dashes in any tracked or new file
	@total=$$(git ls-files -co --exclude-standard | wc -l | tr -d ' '); [ "$$total" -gt 0 ] || { echo "lint-prose: 0 files, nothing checked" >&2; exit 1; }; \
	hits=$$(git ls-files -co --exclude-standard -z | xargs -0 grep -l -I -- $$'\xe2\x80\x94' 2>/dev/null || true); \
	if [ -n "$$hits" ]; then echo "em dash in:"; echo "$$hits"; exit 1; fi; echo "lint-prose: $$total files, 0 em dashes"

docs: ## Regenerate the skill table in docs/SKILLS.md
	@python3 bin/gen-skills-doc.py

docs-check: ## docs/SKILLS.md matches the frontmatter
	@python3 bin/gen-skills-doc.py --check

test: ## unittest for every script
	@python3 -m unittest discover -s tests
