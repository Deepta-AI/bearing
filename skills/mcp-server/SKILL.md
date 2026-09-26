---
name: mcp-server
description: 'Builds an MCP server in Python or TypeScript: schema-checked tools, both transports, auth, a test per tool, Claude Code registration. Use when asked to "build an MCP server" or "expose this as MCP tools".'
argument-hint: "server <name> [python|typescript] | client <agent name> [python|typescript]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(ls:*), Bash(mkdir:*), Bash(uv run pytest:*), Bash(npm test:*), Bash(make:*), Bash(claude mcp list:*), Bash(npx @modelcontextprotocol/inspector:*)
---

# mcp-server

An MCP server is an API whose only client is a model, so its tool
descriptions are its documentation, its schemas are its validation, and
a tool without a protocol-level test is a tool nobody has called. One
server per bounded context; a client maps every discovered tool into
the agent's registry with a tier before the model can see it.

## Inputs

- Tool list: the stories, `docs/genai/<name>-solution.md` or the
  existing API (routes, service methods); if none exist, asks the user
  for the tools (name and purpose) or the API to wrap, in one question.
  Still none: stop with "name at least one tool to expose".
- Stack: `$3`, else `pyproject.toml` versus `package.json`; neither:
  asks.
- Tier mapping (`client`): `mcp/tiers.yaml`; if absent, written with
  every discovered tool at `irreversible` for the user to lower.
- Agent registry (`client`): the one `llm-agent` built; if absent, the
  client keeps its own registry (name, schema, tier, timeout, handler)
  and hands it over later.
- Makefile: `make mcp-dev` when a Makefile exists, else the inspector
  command is printed and run directly.

## Steps

1. Mode and name from `$ARGUMENTS`; stack from `$3` or from
   `pyproject.toml` versus `package.json`. Read `references/mcp-design.md`.
   Load the `claude-api` skill when the client side calls Claude.
2. `server`: list the tools from the stories or the existing API. For
   each: `verb_object` name, a description for a model reader (what it
   returns, when to use it, when not to, limits, error codes), an input
   schema with every field described and bounded, an output shape,
   idempotency, whether it pages, a tier (`read`, `write`,
   `irreversible`) and the annotations that tier implies: `title`,
   `readOnlyHint`, `destructiveHint`, `idempotentHint` and
   `openWorldHint`, all four set explicitly (the table in
   `references/mcp-design.md`). An unset hint makes the host assume
   the worst case. Resources for read-only data the
   model should browse (`resource://<context>/<id>`); prompts for
   task recipes the client can offer. Zero tools: ask once, then
   stop naming what to provide.
3. Write the server from `templates/server-python.md` or
   `templates/server-typescript.md`: both transports (stdio for local
   use, streamable HTTP for a service), bearer or OAuth on HTTP from
   the environment, input validation past the schema (ids exist, ranges
   hold), per-tool timeouts, a rate limit per caller, structured errors
   (`code`, `message`, `retryable`), a request id per call in every
   log line, no secret or token in any tool output, and the tool's
   annotations on its registration.
4. Tests through the protocol: a client session over stdio starts the
   server, `list_tools`, then calls every tool with a valid input, an
   invalid input, and a not-found case, and asserts each listed tool's
   annotations match its tier (a tool with no annotations, or any of
   the four hints unset, fails). The test itself counts: it prints
   `mcp-tools: N exposed, N tested, N annotated` before it asserts and
   fails on zero tools listed or when the three differ (the template's
   test does this; keep it). Run it with the granted command (`uv run
   pytest -s tests/test_mcp_tools.py`, `npm test`, or the `make`
   target) and copy the line; nobody counts by hand.
5. `make mcp-dev` (or the command itself without a Makefile): runs
   `npx @modelcontextprotocol/inspector` against the stdio command. Registration: `.mcp.json` from
   `templates/mcp.json` in the repository root (project scope), or the
   `claude mcp add` line printed for the user. Env var names only,
   never values.
6. `client`: from `templates/client.md`. Connect to each configured
   server (stdio or streamable HTTP), `list_tools`, map each tool into
   the agent's registry (`llm-agent`'s, else the client's own) with a
   tier from the mapping file
   (`mcp/tiers.yaml`: server, tool, tier); an unmapped tool is
   `irreversible` and is reported. Namespace as `<server>__<tool>`.
   Reconnect with backoff on a dropped session; re-list on
   `notifications/tools/list_changed`; a tool that disappears is
   removed from the registry, one that appears is `irreversible` until
   mapped. Timeouts and the request id on every call.
7. Client tests against a fake server (a FastMCP or McpServer instance
   started in the test with two tools): discovery maps both, the
   unmapped one is `irreversible`, a restart reconnects, a list change
   updates the registry, a timed-out call returns `is_error`.
8. Remote-only option: when the agent needs a hosted server and no
   local tools, the Messages API MCP connector (`mcp_servers` plus an
   `mcp_toolset`, beta `mcp-client-2025-11-20`) lets Anthropic hold
   the connection; say in the ADR why it was or was not chosen.
9. Record the ADR, status Accepted only for what the user chose and
   Proposed otherwise, naming no decider who did not decide (`adr`, or a file in `docs/adr/`: server
   boundary, transport, auth); the HLD section when an HLD exists; the
   eval hook is an `llm-eval` follow-up (the agent's trajectories
   exercise the MCP tools). Print the output contract.

## Output contract

```
## MCP <server | client>: <name> (<python | typescript>)
tools: <mcp-tools counts line from the protocol test, verbatim>   resources: N   prompts: N
transports: stdio, streamable-http (:PORT, auth: bearer | oauth | none)
limits: timeout N s per tool, rate N/min per caller
registered: .mcp.json (<server name>) | claude mcp add <line>
client: servers N, tools discovered N, mapped N, unmapped (irreversible) N
tests: N passed   make mcp-dev: ok
ADR: docs/adr/NNNN-<kebab>.md
```

## Gotchas

- A description written for a developer ("returns the order entity")
  is useless to a model. Say what to use it for and when not to.
- Secrets in tool outputs go straight into the model's context and
  the logs. Redact tokens, keys and full card or account numbers in
  the server, not in the client.
- stdio servers must not print to stdout except protocol frames; logs
  go to stderr or a file, or the client sees corrupt JSON.
- A tool that mutates and is not idempotent will be called twice on a
  retry. Take an idempotency key in the schema.
- Annotations are hints the host acts on: `readOnlyHint` may be
  auto-approved, `destructiveHint` gets a confirmation. A refund tool
  with no annotations is not safer; the host guesses. A client never
  lowers a tier because a server's hint says read-only.
- Tool list changes at runtime silently widen the agent's powers. New
  tools are `irreversible` until a person maps them.
- One server per bounded context. A server named `everything` with 40
  tools costs context on every turn and cannot be tiered sensibly.
