---
name: openapi-spec
description: 'Designs or audits the OpenAPI 3.1 contract in api/openapi.yaml, generates readable API docs and counts spec and route drift. Use when asked to "write the OpenAPI spec", "design the API contract" or "check the spec".'
argument-hint: "new <api name> | check [--against <tag>]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(ls:*), Bash(mkdir:*), Bash(command -v:*), Bash(npx @redocly/cli lint:*), Bash(oasdiff:*), Bash(git tag:*), Bash(git show:*), Bash(head -1), Bash(make api-conformance:*), Bash(curl -fsS http://localhost:*), Bash(uv run --quiet --with pyyaml python *skills/openapi-spec/scripts/api_doc.py*), Bash(python3 *skills/openapi-spec/scripts/api_doc.py*)
---

# openapi-spec

The contract comes before the handler. A route that exists only in code
is a private agreement between one developer and one client; the spec
makes it a promise. Drift is reported as counts in both directions, and a
tool that is not installed prints SKIPPED, never a silent pass.

## Inputs

- Mode: looks in `$1`; if absent, `check` when `api/openapi.yaml`
  exists, else `new`.
- Style rules: `references/api-style.md` in this skill.
- Operations for `new`: looks in `docs/product/backlog.md` and the HLD
  interfaces section; if absent, the routes already in the code (the
  step 3 patterns); if none, asks one question for a pasted list of
  operations (method, path, purpose). Zero operations after that stops
  the skill: "provide the stories or a list of operations".
- Auth scheme: looks in `docs/adr/`; if absent, the Decisions first
  protocol decides it, else the spec carries `x-adr-needed: auth`.
- Spec for `check`: `api/openapi.yaml`; if absent, the mode is `new`.
- Template: `templates/openapi.yaml` in this skill.
- Tools: `redocly` and `oasdiff`; if absent, that check prints SKIPPED.
- Readable design: `scripts/api_doc.py` in this skill writes
  `docs/api/API.md` from the spec; it needs PyYAML, which
  uv supplies (Step 7 has the command). Without `uv`, plain `python3` works when
  PyYAML is installed or the spec is JSON; otherwise API.md is "not
  generated (no uv, no PyYAML)" and every other step still runs.

## Steps

**Revising.** When the output file already exists, this run is a
revision: read `${CLAUDE_PLUGIN_ROOT}/skills/adr/references/revision-protocol.md`
and follow it (version line, changes table, superseding ADR,
critic on changed sections, downstream list). In `new` mode on an existing spec, the breaking check also runs against the last committed spec, not only a tag: `mkdir -p .scratch`, `git show HEAD:api/openapi.yaml > .scratch/openapi.v<n>.yaml`, then `oasdiff breaking .scratch/openapi.v<n>.yaml api/openapi.yaml`; each breaking change is a changes-table row whose Impact names `api-versioning`.

**Decisions first.** Before building, run `tech-decision` for the keys api
style. `tech-decision` asks only about the keys this task needs that no
accepted ADR, the request or the code already settles, one question at
a time, and records only what the user decides; a key still
awaiting an answer follows
${CLAUDE_PLUGIN_ROOT}/skills/tech-decision/references/decision-protocol.md.

1. Mode from `$1`: `new` writes a spec; `check` audits one. No argument:
   `check` when `api/openapi.yaml` exists, else `new`. Read
   `references/api-style.md` in both modes.
2. `new`: read the stories and the HLD interfaces section for the
   operations and the ids they serve. Copy `templates/openapi.yaml` to
   `api/openapi.yaml` and fill it: every path and operation with
   `operationId`, `x-story-ids`, request and response schemas that each
   carry an `example`, the shared error envelope on every 4xx and 5xx,
   cursor pagination on every list, the auth scheme from the ADR,
   `X-API-Version` on every operation, and `Idempotency-Key` required on
   every POST that creates or charges. Operations from the sources under
   Inputs; ids `unnumbered` when they came from code or a pasted list.
3. `check`: extract routes from the code, per stack:
   - Go: `HandleFunc("METHOD /path"`, `mux.Handle`, and chi, gin or echo
     `r.Get(`, `r.Post(` and friends;
   - FastAPI: `@router.get("`, `@app.post("` and the router prefix;
   - Express: `app.get(`, `router.post(`;
   - TanStack Start: server routes under `app/routes/api/` and
     `createServerFileRoute`; UI file routes are not API routes.
   Normalise path params (`{id}`, `:id`, `<id>`) to `{id}`. Count routes
   in code and paths in the spec. Both zero: stop with "0 routes in code,
   0 in spec; nothing to compare".
4. Compare: routes in code not in spec; spec operations not in code;
   method mismatches; schema mismatches, checked per route by comparing
   the handler's request and response types with the spec's required
   fields. List each with file and line.
5. Lint: `command -v npx` then `npx @redocly/cli lint api/openapi.yaml`;
   print SKIPPED when unavailable. Breaking changes: the tag from
   `--against` or `git tag --sort=-v:refname | head -1`; write the old
   spec with `git show <tag>:api/openapi.yaml` to `.scratch/`, then
   `oasdiff breaking <old> api/openapi.yaml`; SKIPPED when unavailable
   or when no tag has a spec.
6. Conformance: the grep in step 3 reads the code; this sends real
   requests. Paste `templates/api-conformance.mk` into the Makefile when
   it has no `api-conformance` target, and add a CI job `api-conformance`
   in stage `test` that starts the service (the stack's `docker compose
   up -d --wait` plus `make migrate`) and runs the target with
   `API_BASE_URL` set to it. When a local server answers its health
   route at `API_BASE_URL`, run `make api-conformance` and list each failure with its
   operation and the check that failed (server error, undocumented status,
   response not matching the schema). The server is not running: say
   "conformance: not run (no local server)"; never start one against a
   shared database.
7. Docs: grep for `redoc`, `swagger`, `scalar`, `/docs` to find how the
   repo serves the spec. Write `docs/api/README.md`: where the spec
   lives, the docs route, how to lint, the style rules. No route found:
   write "unconfirmed: no docs route" and name the one to add.
   Then generate the readable design, in both modes, after the spec is
   final: in `new` mode fill the spec's `info.x-api-style`,
   `info.x-versioning` and `info.x-authentication` (one or two sentences
   each), `x-error-codes` on the error envelope (code, status, meaning for
   every code the API returns), tag descriptions, and an operation-level
   `x-error-codes` map where a status has codes of its own. Run
   `uv run --quiet --with pyyaml python "${CLAUDE_PLUGIN_ROOT}/skills/openapi-spec/scripts/api_doc.py" --spec api/openapi.yaml --style "${CLAUDE_PLUGIN_ROOT}/skills/openapi-spec/references/api-style.md" --out docs/api/API.md`
   (`command -v uv` fails: the same with `python3` in place of the `uv
   run` prefix). It writes the header (style, base path, versioning,
   authentication, the error code table), the numbered conventions each
   with its reason, and one section per tag with Serves, the table
   Method, Path, Does, Auth, Success, Errors and the idempotency notes. It
   exits 1 on zero operations. Each finding it prints (no
   `x-story-ids`, a create with no `Idempotency-Key`, a PATCH not marked
   `x-idempotent`, an error status with no declared code) is fixed in the
   spec and the script rerun, or listed in the report. Link API.md from
   `docs/api/README.md`.
8. Print the output contract.

## Output contract

```
## API spec: api/openapi.yaml (new | check)
Paths: N   Operations: N   Schemas: N (missing example: K)
Serves: US-..., AC-US-...
Routes in code: N   Operations in spec: N
  in code, not in spec: K   <METHOD /path> (file:line)
  in spec, not in code: K   <METHOD /path>
  schema mismatches: K      <route>: <field>
Lint: passed | K problems | SKIPPED (redocly not available)
Conformance: N operations, K failures (<operation>: <check>) | not run (<reason>)   CI job: api-conformance added | present
Breaking vs <tag>: 0 | K | SKIPPED (oasdiff not available | no tagged spec)
Docs: docs/api/README.md (served at <route> | unconfirmed)
API doc: docs/api/API.md (<api_doc.py counts line, verbatim>) | not generated (<reason>)
  findings: K   <METHOD /path>: <finding>
Revision: v<n> -> v<n+1>, sections changed C, ADRs superseded S, downstream D | v1 (new)
```

## Gotchas

- A schema without an example is a schema nobody tested against a real
  payload. Count them; they are in the contract.
- Do not "fix" drift by editing the spec to match the code without
  saying so. Report it; the user decides which side is wrong.
- Drift found by grep and conformance found by requests are different
  claims. A route can be in both the code and the spec and still return a
  field the spec does not have; only the conformance run sees that.
- Extraction is grep, not a parser. A route built from a variable or a
  loop is missed; say "extraction is static" in the report.
- Never delete an operation from the spec; deprecate it with
  `deprecated: true` and a `Sunset` header so oasdiff can see it.
- `docs/api/API.md` is generated. Never edit it by hand; change the spec
  (or `references/api-style.md` for a convention) and rerun the script, or
  the page and the contract disagree the day after.
- A convention without its reason is a rule people route around. The
  style reference's numbered list carries a Why on every line; a project
  convention goes in the spec's `x-conventions` as `{rule, why}`.
- No em dashes, including in descriptions inside the YAML.
