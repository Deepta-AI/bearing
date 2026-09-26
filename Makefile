# bearing. `make help` lists targets; `make check` validates the marketplace
# and its three plugins: plugins/bearing (required), plugins/bearing-backend
# and plugins/bearing-apps (the stack skills).
SHELL := /bin/bash
KITP := plugins/bearing
.DEFAULT_GOAL := help
.PHONY: help site devguide wiki check check-file validate lint-skills lint-tools lint-evals lint-neutral lint-docs lint-json lint-shell lint-prose lint-version lint-budget lint-templates lint-plugin-size test install doctor docs harness-eval

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-14s %s\n", $$1, $$2}'

check: validate lint-skills lint-tools lint-evals lint-json lint-shell lint-prose lint-docs lint-neutral lint-version lint-budget lint-templates lint-plugin-size test ## The gate for this repository
	@echo "check: passed"

validate: ## claude plugin validate --strict: the marketplace, then each plugin, its skills and (bearing) its agents
	@n=0; p=0; for t in . $$(for d in plugins/*/; do [ -f "$$d.claude-plugin/plugin.json" ] && echo "$${d%/}"; done); do \
	  out=$$(claude plugin validate --strict "$$t" 2>&1) || { echo "$$out"; exit 1; }; n=$$((n+1)); \
	  [ "$$t" = . ] && continue; p=$$((p+1)); \
	  for sub in skills agents; do [ -d "$$t/$$sub" ] || continue; \
	    out=$$(claude plugin validate --strict "$$t/$$sub" 2>&1) || { echo "$$out"; exit 1; }; n=$$((n+1)); done; \
	done; \
	[ "$$p" -gt 0 ] || { echo "validate: 0 plugins under plugins/, nothing checked" >&2; exit 1; }; \
	echo "validate: $$n targets passed (strict): the marketplace and $$p plugins with their skills and agents"

lint-skills: ## Every skill in every plugin: hyphenated name (64 max) equal to its frontmatter name, sections, description 220 chars max, references exist, bearing:, bearing-backend: and bearing-apps: names resolve
	@n=0; bad=0; per=""; \
	for pl in plugins/*/; do pl="$${pl%/}"; [ -f "$$pl/.claude-plugin/plugin.json" ] || continue; c=$$(ls -d "$$pl"/skills/*/ 2>/dev/null | wc -l | tr -d ' '); per="$$per $$(basename $$pl)=$$c"; done; \
	for d in plugins/*/skills/*/; do \
	  s="$${d%/}"; b="$$(basename $$s)"; f="$$s/SKILL.md"; pr="$${s%/skills/*}"; n=$$((n+1)); \
	  dup=$$(ls -d plugins/*/skills/$$b 2>/dev/null | wc -l | tr -d ' '); [ "$$dup" -eq 1 ] || { echo "skill name in $$dup plugins: $$b"; bad=$$((bad+1)); }; \
	  printf '%s' "$$b" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$$' || { echo "bad name (lowercase words joined by single hyphens): $$b"; bad=$$((bad+1)); }; \
	  [ "$${#b}" -le 64 ] || { echo "name over 64 chars ($${#b}): $$b"; bad=$$((bad+1)); }; \
	  [ -f "$$f" ] || { echo "no SKILL.md: $$b"; bad=$$((bad+1)); continue; }; \
	  grep -q "^name: $$b$$" "$$f" || { echo "name mismatch: $$b"; bad=$$((bad+1)); }; \
	  desc="$$(python3 bin/skill-desc.py "$$f")" || { echo "no description: $$b"; bad=$$((bad+1)); }; \
	  case "$$desc" in *"Use when"*|*"use when"*) ;; *) echo "description lacks 'Use when': $$b"; bad=$$((bad+1));; esac; \
	  len=$$(printf '%s' "$$desc" | wc -m | tr -d ' '); [ "$$len" -le 220 ] || { echo "description over 220 chars ($$len): $$b"; bad=$$((bad+1)); }; \
	  q=$$(printf '%s' "$$desc" | grep -o '"[^"]*"' | wc -l | tr -d ' '); [ "$$q" -ge 2 ] || { echo "description has fewer than 2 quoted trigger phrases ($$q): $$b"; bad=$$((bad+1)); }; \
	  grep -q '^## Gotchas$$' "$$f" || { echo "no '## Gotchas' heading: $$b"; bad=$$((bad+1)); }; \
	  grep -q '^## Inputs$$' "$$f" || { echo "no '## Inputs' section (independence contract): $$b"; bad=$$((bad+1)); }; \
	  if grep -q '^## When this skill is active$$' "$$f"; then \
	    for h in 'Layout' 'On a foreign layout' 'Rules that matter most' 'Commands'; do grep -q "^## $$h$$" "$$f" || { echo "stack skill lacks '## $$h': $$b"; bad=$$((bad+1)); }; done; \
	  else \
	    grep -q '^## Steps$$' "$$f" || { echo "no '## Steps' section: $$b"; bad=$$((bad+1)); }; \
	    grep -q '^## Output contract$$' "$$f" || { echo "no '## Output contract' section: $$b"; bad=$$((bad+1)); }; \
	  fi; \
	  if grep -q '^disable-model-invocation: true' "$$f"; then grep -q '^argument-hint:' "$$f" || { echo "command skill without argument-hint: $$b"; bad=$$((bad+1)); }; fi; \
	  if grep -q 'Decisions first' "$$f"; then grep -E '^allowed-tools:.*(^|[ ,])Skill([ ,]|$$)' "$$f" >/dev/null || { echo "'Decisions first' skill lacks Skill in allowed-tools: $$b"; bad=$$((bad+1)); }; fi; \
	  grep -qE 'Bash\(bash:\*\)|Bash\(git -C' "$$f" && { echo "blanket Bash(bash:*) or Bash(git -C) in allowed-tools: $$b"; bad=$$((bad+1)); }; \
	  for ref in $$(grep -oE '`(references|templates)/[A-Za-z0-9_./-]+`' "$$f" | tr -d '`' | sort -u); do \
	    case "$$ref" in */) ;; *) [ -e "$$s/$$ref" ] || [ -e "$$pr/$$ref" ] || [ -e "$(KITP)/$$ref" ] || [ -e "$$ref" ] || { echo "missing reference in $$b: $$ref"; bad=$$((bad+1)); };; esac; \
	  done; \
	  for tok in $$(grep -oE '\bbearing(-backend|-apps)?:[a-z0-9]+(-[a-z0-9]+)*' "$$f" | sort -u); do \
	    tp="$${tok%%:*}"; tn="$${tok#*:}"; \
	    [ -f "plugins/$$tp/skills/$$tn/SKILL.md" ] || { [ "$$tp" = bearing ] && [ -f "$(KITP)/agents/$$tn.md" ]; } || { echo "unknown name '$$tok' referenced in: $$b"; bad=$$((bad+1)); }; \
	  done; \
	done; \
	a=$$(ls $(KITP)/agents/*.md 2>/dev/null | wc -l | tr -d ' '); h=$$(ls $(KITP)/hooks/scripts/*.sh 2>/dev/null | wc -l | tr -d ' '); t=$$(find $(KITP)/templates -type f | wc -l | tr -d ' '); \
	diff -rq $(KITP)/skills/git-hooks/templates/.githooks $(KITP)/templates/repo/.githooks >/dev/null || { echo "git-hooks templates differ from $(KITP)/templates/repo/.githooks (copy them)"; bad=$$((bad+1)); }; \
	for ag in $(KITP)/agents/*.md; do grep -qE '^tools:.*\(' "$$ag" && { echo "agent tools field must hold bare tool names: $$ag"; bad=$$((bad+1)); }; done; \
	[ "$$n" -gt 0 ] && [ "$$a" -gt 0 ] && [ "$$h" -gt 0 ] && [ "$$t" -gt 0 ] || { echo "empty inventory: $$n skills $$a agents $$h hooks $$t templates" >&2; exit 1; }; \
	[ "$$bad" -eq 0 ] || { echo "lint-skills: $$bad problems"; exit 1; }; \
	echo "lint-skills: $$n skills ($${per# }), $$a agents, $$h hook scripts, $$t template files"

lint-tools: ## Every command a skill body runs is granted by its allowed-tools (bin/lint-skill-tools.allow lists print-only lines)
	@python3 bin/lint-skill-tools.py

lint-evals: ## Every skill has evals (evals/<name>/evals.json, away from the skill) or sits on the shrinking evals/.pending list
	@python3 bin/lint-skill-evals.py

lint-neutral: ## No company name scars, no private tracker names or task-id literals
	@total=$$(git ls-files | wc -l | tr -d ' '); [ "$$total" -gt 0 ] || { echo "lint-neutral: 0 files listed by git, nothing checked" >&2; exit 1; }; \
	hits=$$(git grep -n -I -i -e 'the company workflow' -e 'the company shape' -e 'the company conventions' -e 'the company seat' -e 'the company named in' -e 'an the company' -e 'your the company' -e 'every the company' -e 'for the company' -- . ':!Makefile' | cut -c1-160 | head -20 || true); \
	[ -z "$$hits" ] || { echo "de-branding scars:"; echo "$$hits"; exit 1; }; \
	rs=$$(git grep -n -I -i -E '\bRS-[0-9#]|\bRS_[A-Z]|releas[e][ -]?studio|brg-r[s]\b' -- . ':!CHANGELOG.md' ':!.scratch' | cut -c1-160 | head -20 || true); \
	[ -z "$$rs" ] || { echo "private tracker name or task-id literal (the rest adapter is the public one):"; echo "$$rs"; exit 1; }; \
	echo "lint-neutral: $$total files, 0 scars, 0 private tracker names or literals"

lint-docs: ## Generated docs (SKILLS.md, WORKFLOW.md, the handbook and developer guide data) match their sources
	@tmp=$$(mktemp -d); n=0; stale=0; \
	for f in docs/SKILLS.md docs/WORKFLOW.md site/src/data/handbook.json devguide/src/data/internals.json; do cp "$$f" "$$tmp/$$(basename $$f)"; done; \
	python3 bin/gen-skills-table.py >/dev/null && python3 bin/gen-guide.py >/dev/null && python3 bin/gen-devguide.py >/dev/null || { rm -rf "$$tmp"; exit 1; }; \
	for f in docs/SKILLS.md docs/WORKFLOW.md site/src/data/handbook.json devguide/src/data/internals.json; do n=$$((n+1)); cmp -s "$$f" "$$tmp/$$(basename $$f)" || { echo "stale generated doc regenerated: $$f (commit it)"; stale=$$((stale+1)); }; done; \
	rm -rf "$$tmp"; [ "$$n" -gt 0 ] || exit 1; \
	[ "$$stale" -eq 0 ] || { echo "lint-docs: $$stale of $$n generated docs were stale"; exit 1; }; \
	echo "lint-docs: $$n generated docs up to date"

lint-json: ## Manifests and settings parse
	@n=0; for f in .claude-plugin/marketplace.json $$(ls plugins/*/.claude-plugin/plugin.json) $(KITP)/hooks/hooks.json $(KITP)/templates/repo/.claude/settings.json $$(find plugins -name stack.json | sort) $$(find tests/fixtures -name '*.json' -not -path '*/hostile/*' 2>/dev/null); do \
	  python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$$f" || { echo "invalid JSON: $$f"; exit 1; }; n=$$((n+1)); done; \
	[ "$$n" -gt 0 ] || { echo "lint-json: 0 files parsed, nothing checked" >&2; exit 1; }; echo "lint-json: $$n files parsed"

lint-shell: ## bash -n on every script (shellcheck when installed)
	@n=0; files="install.sh $$(for f in $(KITP)/bin/brg-*; do head -1 "$$f" | grep -qE "bash|/sh" && echo "$$f"; done) $$(ls $(KITP)/hooks/scripts/*.sh) $$(ls $(KITP)/templates/repo/.githooks/*) $$(find plugins -path "*/skills/*/scripts/*.sh" | sort) $$(find tests -name "*.sh" | sort)"; \
	for f in $$files; do bash -n "$$f" || exit 1; n=$$((n+1)); done; \
	[ "$$n" -gt 0 ] || { echo "lint-shell: 0 scripts parsed, nothing checked" >&2; exit 1; }; \
	if command -v shellcheck >/dev/null; then shellcheck -S warning -e SC2034,SC2010,SC2088 $$files && echo "lint-shell: $$n scripts, shellcheck clean"; \
	else echo "lint-shell: $$n scripts parsed (shellcheck not installed, static analysis SKIPPED)"; fi

check-file: ## Lint one edited file, FILE=path (the edit hook runs this; the same flags as lint-shell and lint-json)
	@[ -n "$(FILE)" ] || { echo "check-file: FILE is empty, nothing checked" >&2; exit 1; }; \
	[ -f "$(FILE)" ] || { echo "check-file: $(FILE) does not exist, nothing checked" >&2; exit 1; }; \
	case "$(FILE)" in \
	  *.sh|bin/brg-*|*/bin/brg-*|templates/repo/.githooks/*|*/templates/repo/.githooks/*) bash -n "$(FILE)" || exit 1; \
	    command -v shellcheck >/dev/null || { echo "check-file: shellcheck not installed, $(FILE) parsed only"; exit 0; }; \
	    shellcheck -S warning -e SC2034,SC2010,SC2088 "$(FILE)" || exit 1;; \
	  *.json) python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$(FILE)" || exit 1;; \
	  *.py) python3 -m py_compile "$(FILE)" || exit 1;; \
	  *) echo "check-file: no per-file check for $(FILE)"; exit 0;; \
	esac; \
	echo "check-file: 1 file checked"

lint-prose: ## No em dashes in anything we ship (every tracked or unignored file; .gitignore keeps out node_modules and builds)
	@total=$$(git ls-files -co --exclude-standard | wc -l | tr -d ' '); [ "$$total" -gt 0 ] || { echo "lint-prose: 0 files, nothing checked" >&2; exit 1; }; \
	hits=$$(git ls-files -co --exclude-standard -z | xargs -0 grep -n -I -- '—' 2>/dev/null | grep -v -e "'—'" -e '"—"' -e '`—`' | cut -d: -f1 | sort -u || true); \
	if [ -n "$$hits" ]; then echo "em dash in:"; echo "$$hits"; exit 1; fi; echo "lint-prose: $$total files, 0 em dashes"

lint-templates: ## Every document template says what goes in each section and what good looks like
	@python3 bin/lint-templates.py

lint-budget: ## What every session loads stays small: AGENTS.md, CLAUDE.md and the unscoped rules, in bytes
	@n=0; bad=0; \
	for pair in $(KITP)/templates/repo/AGENTS.md:3600 $(KITP)/templates/repo/CLAUDE.md:1500; do f=$${pair%%:*}; max=$${pair##*:}; \
	  [ -f "$$f" ] || { echo "lint-budget: $$f missing"; bad=$$((bad+1)); continue; }; \
	  b=$$(wc -c < "$$f" | tr -d ' '); n=$$((n+1)); [ "$$b" -le "$$max" ] || { echo "lint-budget: $$f is $$b bytes, budget $$max"; bad=$$((bad+1)); }; done; \
	unscoped=0; for f in $(KITP)/templates/repo/.claude/rules/*.md; do n=$$((n+1)); head -5 "$$f" | grep -q '^paths:' || unscoped=$$((unscoped + $$(wc -c < "$$f" | tr -d ' '))); done; \
	[ "$$unscoped" -le 1200 ] || { echo "lint-budget: unscoped rules total $$unscoped bytes, budget 1200"; bad=$$((bad+1)); }; \
	[ "$$n" -gt 0 ] || { echo "lint-budget: 0 files, nothing checked" >&2; exit 1; }; \
	[ "$$bad" -eq 0 ] || exit 1; \
	echo "lint-budget: $$n files checked; AGENTS.md $$(wc -c < $(KITP)/templates/repo/AGENTS.md | tr -d ' ') and CLAUDE.md $$(wc -c < $(KITP)/templates/repo/CLAUDE.md | tr -d ' ') bytes, unscoped rules $$unscoped bytes (about $$(( ($$(wc -c < $(KITP)/templates/repo/AGENTS.md) + $$(wc -c < $(KITP)/templates/repo/CLAUDE.md) + $$unscoped) / 4 )) tokens a session)"

lint-version: ## VERSION matches every plugin.json, the marketplace metadata and every marketplace entry (the three plugins move in lockstep)
	@python3 bin/lint-version.py

lint-plugin-size: ## Each plugin folder holds under 512 files and no non-image, non-font file of 256 KiB or more (the plugin directory's limits); prints the count per plugin
	@python3 bin/lint-plugin-size.py

test: ## Unit and integration tests under tests/
	@bash tests/run.sh

harness-eval: ## Real Claude Code sessions against the hooks: push, deploy, edit lint, stop gate (green and red), compaction (uses the claude CLI; not part of check)
	python3 bin/harness-eval.py $(if $(ONLY),--only $(ONLY))

install: ## Install on this machine
	bash install.sh

doctor: ## Verify this machine
	bash bin/brg-doctor

docs: ## Regenerate docs/SKILLS.md, docs/WORKFLOW.md, the repo skills maps, the handbook data and the developer guide data
	@python3 bin/gen-skills-table.py
	@python3 bin/gen-guide.py
	@python3 bin/gen-devguide.py

wiki: ## Export the docs and flows as wiki pages into WIKI_DIR (a clone of the project's .wiki.git); REPO_URL is the repository's web URL for file links
	@[ -n "$(WIKI_DIR)" ] || { echo "wiki: set WIKI_DIR to a clone of the wiki repository (git clone <repo>.wiki.git)" >&2; exit 1; }
	@python3 bin/gen-wiki.py "$(WIKI_DIR)" $(if $(REPO_URL),--repo-url "$(REPO_URL)")
	@echo "wiki: now commit and push in $(WIKI_DIR) (git -C $(WIKI_DIR) status shows the changed pages)"

site: ## Build the handbook site into site/dist (node 22 and pnpm); the data comes from make docs
	@python3 bin/gen-guide.py >/dev/null
	@cd site && pnpm install --frozen-lockfile --silent && pnpm build

devguide: ## Build the developer guide (how Bearing works inside) into devguide/dist (node 22 and pnpm); the data comes from make docs
	@python3 bin/gen-guide.py >/dev/null
	@python3 bin/gen-devguide.py
	@cd devguide && pnpm install --frozen-lockfile --silent && pnpm build
