# __REPO_NAME__ (Go service). Every command lives here. `make help` lists them.
SHELL := /bin/bash
.DEFAULT_GOAL := help
GOFLAGS ?=
PKG := ./...
BIN := bin/api
STATE := .bearing/state
SKIPPED := $(STATE)/.skipped
# The gates `make check` runs, in order. test-integration needs Postgres, so
# it is a CI job and a manual target, not part of check.
GATES := fmt-check vet lint test vuln
DATABASE_URL ?= postgres://postgres:postgres@localhost:5432/__REPO_SLUG__?sslmode=disable
PSQL_URL = $(DATABASE_URL)
# The pinned tools (tools/go.mod) install here; make finds them first.
TOOLS_BIN := $(CURDIR)/bin/tools
export PATH := $(TOOLS_BIN):$(PATH)
GO_FILES = $(shell find . -name '*.go' -not -path './vendor/*' -not -path './.git/*' -not -path './internal/store/*.sql.go')

# $(call skip,gate,tool): the tool is absent. Print it, record it, and let the
# other gates run; `check` fails on any recorded skip. Never a silent pass.
define skip
{ mkdir -p $(STATE); echo "$(1): SKIPPED ($(2) not installed)"; echo "$(1) $(2)" >> $(SKIPPED); exit 0; }
endef

.PHONY: help setup tools dev build check check-file fmt fmt-check vet lint test test-integration vuln fix migrate migrate-verify migrate-down migrate-status sqlc doctor clean db db-reset

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-18s %s\n", $$1, $$2}'

setup: ## Tidy both modules (writes go.sum and tools/go.sum), install the pinned tools and git hooks
	go mod tidy
	go -C tools mod tidy
	@$(MAKE) --no-print-directory tools
	bash .githooks/install.sh
	@echo "setup done; commit go.sum and tools/go.sum if they changed"

tools: ## Install the tools pinned in tools/go.mod into bin/tools
	@[ -f tools/go.sum ] || { echo "tools: no tools/go.sum committed; resolving it now (run make setup and commit tools/go.sum)"; go -C tools mod tidy; }
	@GOBIN="$(TOOLS_BIN)" go -C tools install tool
	@n=$$(ls "$(TOOLS_BIN)" 2>/dev/null | wc -l | tr -d ' '); \
	[ "$$n" -gt 0 ] || { echo "tools: 0 tools installed from tools/go.mod" >&2; exit 1; }; \
	echo "tools: $$n tools installed from tools/go.mod"

dev: ## Run the API locally (reads .env if present)
	@set -a; [ -f .env ] && . ./.env; set +a; go run ./cmd/api

build: ## Build the binary
	CGO_ENABLED=0 go build $(GOFLAGS) -ldflags="-s -w -X main.version=$$(git describe --tags --always --dirty)" -o $(BIN) ./cmd/api

fmt: ## Format
	gofmt -w $(GO_FILES)

fmt-check: ## Fail if any file is unformatted
	@n=$$(echo $(GO_FILES) | wc -w | tr -d ' '); \
	[ "$$n" -gt 0 ] || { echo "fmt-check: 0 go files, nothing checked" >&2; exit 1; }; \
	command -v gofmt >/dev/null || $(call skip,fmt-check,gofmt); \
	files=$$(gofmt -l $(GO_FILES)); \
	[ -z "$$files" ] || { echo "unformatted (run make fix):"; echo "$$files"; exit 1; }; \
	echo "fmt-check: $$n files checked"

vet: ## go vet every package
	@n=$$(go list $(PKG) | wc -l | tr -d ' '); \
	[ "$$n" -gt 0 ] || { echo "vet: 0 packages, nothing checked" >&2; exit 1; }; \
	go vet $(PKG) && echo "vet: $$n packages checked"

lint: ## golangci-lint (.golangci.yml)
	@n=$$(go list $(PKG) | wc -l | tr -d ' '); \
	[ "$$n" -gt 0 ] || { echo "lint: 0 packages, nothing checked" >&2; exit 1; }; \
	command -v golangci-lint >/dev/null || $(call skip,lint,golangci-lint); \
	golangci-lint run ./... && echo "lint: $$n packages checked"

test: ## Unit tests with race detector
	@n=$$(go list $(PKG) | wc -l | tr -d ' '); \
	[ "$$n" -gt 0 ] || { echo "test: 0 packages, nothing checked" >&2; exit 1; }; \
	set -o pipefail; go test -race -count=1 -cover $(PKG) 2>&1 | tail -60 && echo "test: $$n packages checked"

test-integration: ## Store tests against Postgres (needs make db and make migrate; a CI job, not part of check)
	@n=$$(go list -tags=integration ./internal/store/... | wc -l | tr -d ' '); \
	[ "$$n" -gt 0 ] || { echo "test-integration: 0 packages, nothing checked" >&2; exit 1; }; \
	set -o pipefail; DATABASE_URL=$(DATABASE_URL) go test -race -count=1 -tags=integration ./internal/store/... 2>&1 | tail -60 && echo "test-integration: $$n packages checked"

vuln: ## govulncheck over the module graph
	@command -v govulncheck >/dev/null || $(call skip,vuln,govulncheck); \
	n=$$(go list -m all | wc -l | tr -d ' '); [ "$$n" -gt 0 ] || { echo "vuln: 0 modules, nothing checked" >&2; exit 1; }; \
	govulncheck ./... && echo "vuln: $$n modules checked"

check: ## The gate: every gate in GATES, then the tally. CI runs exactly this.
	@mkdir -p $(STATE); rm -f $(SKIPPED) $(STATE)/.check-passed
	@for g in $(GATES); do $(MAKE) --no-print-directory $$g || { echo "check: $$g failed" >&2; exit 1; }; done
	@s=$$(cut -d' ' -f1 $(SKIPPED) 2>/dev/null | sort -u | wc -l | tr -d ' '); r=$$(( $(words $(GATES)) - s )); \
	echo "check: $$r gates run, $$s skipped"; \
	if [ "$$s" -eq 0 ]; then touch $(STATE)/.check-passed; echo "check: passed"; \
	elif [ "$${BEARING_ALLOW_SKIP:-0}" = "1" ] && [ -z "$$CI" ]; then sed 's/^/  skipped: /' $(SKIPPED); echo "check: passed with skips (BEARING_ALLOW_SKIP=1 is a local convenience; CI never sets it)"; \
	else sed 's/^/  skipped: /' $(SKIPPED); echo "check: FAILED, $$s gate(s) skipped; run make setup, or BEARING_ALLOW_SKIP=1 make check locally" >&2; exit 1; fi

check-file: ## Lint one edited file, FILE=path (the Bearing edit hook runs this)
	@[ -n "$(FILE)" ] || { echo "check-file: FILE is empty, nothing checked" >&2; exit 1; }; \
	[ -f "$(FILE)" ] || { echo "check-file: $(FILE) does not exist, nothing checked" >&2; exit 1; }; \
	case "$(FILE)" in \
	  *.go) command -v go >/dev/null || { echo "check-file: go not installed, $(FILE) not checked"; exit 0; }; go vet "./$$(dirname "$(FILE)")" || exit 1;; \
	  *) echo "check-file: no per-file check for $(FILE)"; exit 0;; \
	esac; \
	echo "check-file: 1 file checked"

fix: fmt ## Apply every automatic fix
	@command -v golangci-lint >/dev/null && golangci-lint run --fix ./... || true

db: ## Start Postgres in Docker
	docker compose up -d postgres

db-reset: ## Drop and recreate the local database (destructive)
	docker compose down -v && docker compose up -d postgres

migrate: ## goose up
	goose -dir db/migrations postgres "$(DATABASE_URL)" up

migrate-down: ## goose down one
	goose -dir db/migrations postgres "$(DATABASE_URL)" down

migrate-verify: ## Every Down runs and restores the schema: up, snapshot, down, up, snapshot, diff (a CI step; needs psql)
	@command -v psql >/dev/null || { echo "migrate-verify: psql not installed (postgresql-client), nothing checked" >&2; exit 1; }; \
	[ -f scripts/schema-snapshot.sql ] || { echo "migrate-verify: no scripts/schema-snapshot.sql, nothing checked" >&2; exit 1; }; \
	n=$$(ls db/migrations/*.sql 2>/dev/null | wc -l | tr -d ' '); \
	[ "$$n" -gt 0 ] || { echo "migrate-verify: 0 migrations in db/migrations, nothing checked" >&2; exit 1; }; \
	mkdir -p $(STATE); snap() { psql "$(PSQL_URL)" -XAtq -v ON_ERROR_STOP=1 -f scripts/schema-snapshot.sql > "$(STATE)/schema-$$1.txt"; }; \
	$(MAKE) --no-print-directory migrate >/dev/null && snap up || exit 1; \
	o=$$(wc -l < $(STATE)/schema-up.txt | tr -d ' '); [ "$$o" -gt 0 ] || { echo "migrate-verify: the schema snapshot is empty, nothing compared" >&2; exit 1; }; \
	$(MAKE) --no-print-directory migrate-down >/dev/null && $(MAKE) --no-print-directory migrate >/dev/null && snap newest || exit 1; \
	diff -u $(STATE)/schema-up.txt $(STATE)/schema-newest.txt || { echo "migrate-verify: the newest Down does not undo exactly what its Up did" >&2; exit 1; }; \
	goose -dir db/migrations postgres "$(DATABASE_URL)" reset >/dev/null && $(MAKE) --no-print-directory migrate >/dev/null && snap all || exit 1; \
	diff -u $(STATE)/schema-up.txt $(STATE)/schema-all.txt || { echo "migrate-verify: running every Down and every Up again changed the schema" >&2; exit 1; }; \
	echo "migrate-verify: $$n migrations, every Down ran, $$o schema objects identical after down and up"

migrate-status: ## goose status
	goose -dir db/migrations postgres "$(DATABASE_URL)" status

sqlc: ## Regenerate typed queries
	sqlc generate

doctor: ## Environment diagnostics
	@echo "go:          $$(go version)"
	@echo "go.sum:      $$([ -f go.sum ] && echo present || echo 'MISSING (run make setup)')"
	@echo "golangci:    $$(command -v golangci-lint >/dev/null && golangci-lint version 2>/dev/null | head -1 || echo missing)"
	@echo "tools:       $$(ls $(TOOLS_BIN) 2>/dev/null | tr '\n' ' ' || true)(bin/tools from tools/go.mod; make tools)"
	@echo "govulncheck: $$(command -v govulncheck >/dev/null && echo present || echo missing)"
	@echo "sqlc:        $$(command -v sqlc >/dev/null && sqlc version || echo missing)"
	@echo "goose:       $$(command -v goose >/dev/null && goose -version || echo missing)"
	@echo "docker:      $$(command -v docker >/dev/null && docker --version || echo missing)"
	@echo "hooksPath:   $$(git config core.hooksPath || echo 'NOT SET (run make setup)')"

clean: ## Remove build output
	rm -rf bin coverage.out $(STATE)/.check-passed $(SKIPPED)
