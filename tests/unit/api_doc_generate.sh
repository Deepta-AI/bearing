#!/usr/bin/env bash
# tests/unit/api_doc_generate.sh: plugins/bearing/skills/openapi-spec/scripts/api_doc.py writes
# docs/api/API.md from an OpenAPI spec: header (style, base path, versioning,
# authentication, error code table), numbered conventions with reasons from
# the style reference, one section per tag with Serves and the operation
# table, idempotency notes, findings; and it fails on zero operations. The
# fixture spec is JSON (valid YAML) so the test needs no PyYAML.
set -u
. "$(dirname "$0")/../lib/assert.sh"
AD="$KIT/plugins/bearing/skills/openapi-spec/scripts/api_doc.py"
STYLE="$KIT/plugins/bearing/skills/openapi-spec/references/api-style.md"

spec() { cat > "$1" <<'JSON'
{
  "openapi": "3.1.0",
  "info": { "title": "Invoices API", "version": "1.2.0",
            "x-api-style": "REST over HTTPS with JSON bodies.",
            "x-versioning": "Major in the path; dated changes in X-API-Version." },
  "servers": [ { "url": "https://api.example.com/api/v1" } ],
  "security": [ { "bearerAuth": [] } ],
  "tags": [ { "name": "invoices", "description": "Bills sent to customers." },
            { "name": "customers", "description": "Parties a tenant bills." } ],
  "paths": {
    "/invoices": {
      "get": { "tags": ["invoices"], "summary": "List invoices", "x-story-ids": ["US-01-003"],
               "responses": { "200": { "description": "One page" },
                              "401": { "$ref": "#/components/responses/Unauthorized" } } },
      "post": { "tags": ["invoices"], "summary": "Create an invoice", "x-story-ids": ["US-01-002"],
                "parameters": [ { "$ref": "#/components/parameters/IdempotencyKey" } ],
                "x-error-codes": { "409": ["idempotency_conflict"] },
                "responses": { "201": { "description": "Created" },
                               "409": { "description": "Conflict" },
                               "422": { "description": "Invalid" } } }
    },
    "/invoices/{id}": {
      "patch": { "tags": ["invoices"], "summary": "Edit a draft", "x-story-ids": ["US-01-002"],
                 "responses": { "200": { "description": "Updated" }, "418": { "description": "Teapot" } } },
      "delete": { "tags": ["invoices"], "summary": "Void a draft", "x-story-ids": ["US-01-004"],
                  "responses": { "204": { "description": "Voided" } } }
    },
    "/customers": {
      "post": { "tags": ["customers"], "summary": "Add a customer", "x-story-ids": ["US-01-001"],
                "responses": { "201": { "description": "Created" } } }
    },
    "/health": {
      "get": { "summary": "Liveness", "security": [], "responses": { "200": { "description": "Up" } } }
    }
  },
  "components": {
    "securitySchemes": { "bearerAuth": { "type": "http", "scheme": "bearer", "bearerFormat": "JWT" } },
    "parameters": { "IdempotencyKey": { "name": "Idempotency-Key", "in": "header", "required": true,
                                         "description": "Client UUID; replays for 24 hours." } },
    "responses": { "Unauthorized": { "description": "Missing token" } },
    "schemas": {
      "Error": { "type": "object", "x-error-codes": [
        { "code": "unauthorized", "status": 401, "meaning": "No or bad token." },
        { "code": "idempotency_conflict", "status": 409, "meaning": "Key reused with another body." },
        { "code": "invoice_not_draft", "status": 409, "meaning": "Only a draft can change." },
        { "code": "unprocessable", "status": 422, "meaning": "Content breaks a rule." } ] }
    }
  }
}
JSON
}

t_begin "an operation's operationId is named beside what it does"
d="$(tmpdir)"; spec "$d/openapi.yaml"
replace_in "$d/openapi.yaml" '"get": { "summary": "Liveness",' '"get": { "summary": "Liveness", "operationId": "getHealth",'
assert_exit 0 python3 "$AD" --spec "$d/openapi.yaml" --style "$STYLE" --out "$d/docs/api/API.md"
assert_contains "$(cat "$d/docs/api/API.md")" "| GET | \`/health\` | Liveness (\`getHealth\`) | none | 200 Up | none |"
t_end

t_begin "a spec becomes API.md with header, conventions, resources and counts"
d="$(tmpdir)"; spec "$d/openapi.yaml"
assert_exit 0 python3 "$AD" --spec "$d/openapi.yaml" --style "$STYLE" --out "$d/docs/api/API.md"
assert_contains "$T_OUT" "api-doc: 6 operations in 3 resources, 4 paths, 4 error codes, 10 conventions, 4 stories, 4 findings -> $d/docs/api/API.md"
assert_file "$d/docs/api/API.md"
doc="$(cat "$d/docs/api/API.md")"
assert_contains "$doc" "# API: Invoices API v1.2.0"
assert_contains "$doc" "**Style:** REST over HTTPS with JSON bodies. · **Base path:** \`/api/v1\` · **Versioning:** Major in the path"
assert_contains "$doc" "**Authentication.** Schemes: \`bearerAuth\`: bearer (JWT). Global requirement: bearerAuth."
assert_contains "$doc" "Public operations: GET /health."
assert_contains "$doc" "| \`invoice_not_draft\` | 409 | Only a draft can change. |"
assert_contains "$doc" "7. Every POST that creates or charges requires \`Idempotency-Key\`"
assert_contains "$doc" "Why: mobile networks retry"
assert_contains "$doc" "## invoices"
assert_contains "$doc" "Serves US-01-003, US-01-002, US-01-004."
assert_contains "$doc" "| GET | \`/invoices\` | List invoices | bearerAuth | 200 One page | 401 unauthorized |"
assert_contains "$doc" "| POST | \`/invoices\` | Create an invoice | bearerAuth | 201 Created | 409 idempotency_conflict, 422 unprocessable |"
assert_contains "$doc" "| GET | \`/health\` | Liveness | none | 200 Up | none |"
assert_contains "$doc" "- \`POST /invoices\`: Idempotency-Key required. Client UUID; replays for 24 hours."
assert_contains "$doc" "- \`DELETE /invoices/{id}\`: idempotent by definition"
assert_contains "$doc" "Serves: unnumbered (no x-story-ids)."
t_end

t_begin "findings name the missing story ids, idempotency gaps and undeclared codes"
d="$(tmpdir)"; spec "$d/openapi.yaml"
assert_exit 0 python3 "$AD" --spec "$d/openapi.yaml" --style "$STYLE" --out "$d/API.md"
assert_contains "$T_OUT" "GET /health: no x-story-ids"
assert_contains "$T_OUT" "POST /customers: creates (201) with no Idempotency-Key"
assert_contains "$T_OUT" "PATCH /invoices/{id}: PATCH not documented as idempotent"
assert_contains "$T_OUT" "PATCH /invoices/{id}: 418 has no declared error code in x-error-codes"
assert_contains "$(cat "$d/API.md")" "## Findings"
t_end

t_begin "zero operations, a missing spec and a style with no conventions fail, writing nothing"
d="$(tmpdir)"
printf '{"openapi": "3.1.0", "info": {"title": "x", "version": "1"}, "paths": {}}\n' > "$d/empty.yaml"
assert_exit 1 python3 "$AD" --spec "$d/empty.yaml" --out "$d/API.md"
assert_contains "$T_OUT" "api-doc: 0 operations in $d/empty.yaml, nothing written"
assert_exit 1 test -e "$d/API.md"
assert_exit 1 python3 "$AD" --spec "$d/none.yaml" --out "$d/API.md"
assert_contains "$T_OUT" "api-doc: 0 operations, nothing written (no spec at $d/none.yaml)"
spec "$d/openapi.yaml"; printf '# Style\n\n- no numbered rules here\n' > "$d/style.md"
assert_exit 1 python3 "$AD" --spec "$d/openapi.yaml" --style "$d/style.md" --out "$d/API.md"
assert_contains "$T_OUT" "api-doc: 0 conventions in $d/style.md"
assert_exit 1 test -e "$d/API.md"
t_end

t_summary
