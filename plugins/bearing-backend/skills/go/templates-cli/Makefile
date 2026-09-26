# __REPO_NAME__ (Go command-line tool). Every command lives here. `make help` lists them.
SHELL := /bin/bash
.DEFAULT_GOAL := help
GOFLAGS ?=
PKG := ./...
BIN := bin/__REPO_SLUG__
# git describe fails before the first commit; the binary then says dev.
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
STATE := .bearing/state
SKIPPED := $(STATE)/.skipped
# The gates `make check` runs, in order.
GATES := fmt-check vet lint test vuln
# The pinned tools (tools/go.mod) install here; make finds them first.
TOOLS_BIN := $(CURDIR)/bin/tools
export PATH := $(TOOLS_BIN):$(PATH)
GO_FILES = $(shell find . -name '*.go' -not -path './vendor/*' -not -path './.git/*')

# $(call skip,gate,tool): the tool is absent. Print it, record it, and let the
# other gates run; `check` fails on any recorded skip. Never a silent pass.
define skip
{ mkdir -p $(STATE); echo "$(1): SKIPPED ($(2) not installed)"; echo "$(1) $(2)" >> $(SKIPPED); exit 0; }
endef

.PHONY: help setup tools run build check check-file fmt fmt-check vet lint test vuln fix doctor clean

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-18s %s\n", $$1, $$2}'

setup: ## Tidy both modules (writes tools/go.sum, and go.sum once there is a dependency), install the pinned tools and git hooks
	go mod tidy
	go -C tools mod tidy
	@$(MAKE) --no-print-directory tools
	bash .githooks/install.sh
	@echo "setup done; commit go.mod, go.sum (when present) and tools/go.sum if they changed"

tools: ## Install the tools pinned in tools/go.mod into bin/tools
	@[ -f tools/go.sum ] || { echo "tools: no tools/go.sum committed; resolving it now (run make setup and commit tools/go.sum)"; go -C tools mod tidy; }
	@GOBIN="$(TOOLS_BIN)" go -C tools install tool
	@n=$$(ls "$(TOOLS_BIN)" 2>/dev/null | wc -l | tr -d ' '); \
	[ "$$n" -gt 0 ] || { echo "tools: 0 tools installed from tools/go.mod" >&2; exit 1; }; \
	echo "tools: $$n tools installed from tools/go.mod"

run: ## Run the tool from source, ARGS="greet --name Ada"
	go run -ldflags="-X main.version=$(VERSION)" ./cmd/__REPO_SLUG__ $(ARGS)

build: ## Build the binary into bin/__REPO_SLUG__ (BIN= and GOOS/GOARCH cross-compile)
	CGO_ENABLED=0 go build $(GOFLAGS) -trimpath -ldflags="-s -w -X main.version=$(VERSION)" -o $(BIN) ./cmd/__REPO_SLUG__

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

vuln: ## govulncheck over the module graph and the standard library
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

doctor: ## Environment diagnostics
	@echo "go:          $$(go version)"
	@echo "go.sum:      $$([ -f go.sum ] && echo present || echo 'none (standard library only until the first dependency; make setup writes it)')"
	@echo "tools sum:   $$([ -f tools/go.sum ] && echo present || echo 'MISSING (run make setup)')"
	@echo "golangci:    $$(command -v golangci-lint >/dev/null && golangci-lint version 2>/dev/null | head -1 || echo missing)"
	@echo "tools:       $$(ls $(TOOLS_BIN) 2>/dev/null | tr '\n' ' ' || true)(bin/tools from tools/go.mod; make tools)"
	@echo "govulncheck: $$(command -v govulncheck >/dev/null && echo present || echo missing)"
	@echo "hooksPath:   $$(git config core.hooksPath || echo 'NOT SET (run make setup)')"

clean: ## Remove build output
	rm -rf bin coverage.out $(STATE)/.check-passed $(SKIPPED)
