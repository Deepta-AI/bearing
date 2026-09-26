# api-conformance: the running API against api/openapi.yaml. Schemathesis
# generates requests from every operation's schema (valid, boundary and
# invalid), sends them to API_BASE_URL and fails on a 5xx, a response the
# spec does not describe, a status code the spec does not list, a wrong
# content type or a missing required header. It runs against a local or
# qa server only. openapi-spec pastes this block into the Makefile.
API_BASE_URL ?= http://localhost:8080
CONFORMANCE_EXAMPLES ?= 25

.PHONY: api-conformance
api-conformance: ## The running API against api/openapi.yaml (schemathesis; needs the server up)
	@[ -f api/openapi.yaml ] || { echo "api-conformance: no api/openapi.yaml, nothing checked" >&2; exit 1; }; \
	case "$(API_BASE_URL)" in *prod*|*production*) echo "api-conformance: refusing $(API_BASE_URL); local or qa only" >&2; exit 1;; esac; \
	command -v uvx >/dev/null || { echo "api-conformance: uvx not installed (uv), nothing checked" >&2; exit 1; }; \
	n=$$(grep -c 'operationId:' api/openapi.yaml); [ "$$n" -gt 0 ] || { echo "api-conformance: 0 operations in api/openapi.yaml, nothing checked" >&2; exit 1; }; \
	uvx schemathesis@4.28.0 run api/openapi.yaml --url "$(API_BASE_URL)" --checks all --max-examples $(CONFORMANCE_EXAMPLES) $(if $(API_TOKEN),--header "Authorization: Bearer $(API_TOKEN)") && \
	echo "api-conformance: $$n operations checked against $(API_BASE_URL)"
