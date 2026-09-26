---
name: llm-gateway
description: 'Puts every LLM call behind one gateway module: routing by model tier, retries, timeouts, rate limits, caching, cost tracking, fallbacks. Use when asked to "add an LLM call", "track LLM cost" or "find every model call".'
argument-hint: "[audit] [--stack python|typescript]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(ls:*), Bash(make:*), Bash(git status:*), Bash(git diff:*), Bash(python3 -c:*), Bash(uv run pytest:*), Bash(npm test:*), Bash(pnpm test:*), Bash(python3 *skills/llm-gateway/scripts/llm_callsites_check.py*), Bash(python3 *skills/llm-gateway/scripts/llm_access_check.py*)
---

# llm-gateway

A model call is a network call to a metered, rate-limited, sometimes
refusing dependency. It gets the same discipline as a payment gateway:
one module, one interface, every call counted. A `messages.create`
outside `llm/` is a finding.

## Inputs

- Features, tiers and volume: `docs/genai/*-solution.md`; if absent,
  asks the task, the scale and the model tier in one question and
  writes the first route from the answer.
- Stack: `--stack`, else `pyproject.toml` versus `package.json`;
  neither: asks.
- Meter and tracer: the ones `observability` wired; if absent, the
  gateway creates its own and the stack wiring is a follow-up. `make`
  targets when a Makefile exists, else `uv run pytest` or `npm test`.
- Call-site gate: `scripts/llm_callsites_check.py` in this skill,
  Python 3 only; its header lists the provider patterns it counts.

## Steps

**Decisions first.** Before building, run `tech-decision` for the keys llm
provider and models. `tech-decision` asks only about the keys this task needs that no
accepted ADR, the request or the code already settles, one question at
a time, and records only what the user decides; a key still
awaiting an answer follows
${CLAUDE_PLUGIN_ROOT}/skills/tech-decision/references/decision-protocol.md.

1. Stack from `--stack` or the repo (`pyproject.toml` or `package.json`).
   Both present: one gateway per service, same interface.
2. Audit call sites with the call-site gate:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/llm-gateway/scripts/llm_callsites_check.py" .`
   It counts every Anthropic client, call, SDK import and endpoint and
   the other providers (`openai`, `google.genai`, `mistralai`,
   `cohere`, `ollama`) from the code, and prints an `outside:` line per
   call site outside `llm/`. Here its exit code is the inventory, not
   the gate: before the gateway exists it exits 1 (zero call sites, or
   every site outside). Copy its counts line. Zero call sites and no
   `audit` flag: continue, the gateway is being built ahead of the
   first feature. `audit` alone: report and stop.
3. Write `llm/gateway.py` from `templates/gateway-python.md` or
   `src/llm/gateway.ts` from `templates/gateway-typescript.md`. The
   interface: `complete(req: LLMRequest) -> LLMResponse`, `stream(req)`,
   and `parse(req, schema)`. `LLMRequest` carries `feature`, `tenant_id`,
   `tier`, `system`, `messages`, `tools`, `max_tokens`,
   `idempotency_key`. Providers implement `Provider.complete`; Anthropic
   is the first, others sit behind the same class: `openrouter` (one key,
   many vendors, a spend limit per key; the OpenAI-compatible API at
   `https://openrouter.ai/api/v1`), `openai`, and `vllm` or
   `openai_compatible` for a served open model (`llm-fine-tuning`).
4. Routing in `llm/routing.yaml` from `templates/routing.yaml`: tiers
   `fast` (`claude-haiku-4-5`: classification, routing, short
   extraction), `balanced` (`claude-sonnet-5`: bulk generation, RAG
   answers, judges of short outputs) and `deep` (`claude-opus-5`, the
   default: reasoning, planning, anything a user reads). Each route
   names a feature, a tier, `effort`, `max_tokens`, `timeout_s`,
   `cacheable`, `fallback`, `enabled`, `canary`. The schema is
   validated at startup; an unknown feature fails the call, not the
   boot.
5. Resilience. Retries: the SDK's `max_retries` (default 2, backoff on
   408, 409, 429, 5xx) plus one gateway retry on 529 with jitter;
   never retry a 400. Idempotency: a client-supplied key stores the
   completed response for 24 hours so a retried request through the
   gateway is not billed twice. Timeouts per route (Python seconds,
   TypeScript milliseconds). Rate limit per tenant with a token bucket
   keyed by `tenant_id` and tier; over limit returns a typed
   `RateLimited` error the edge maps to 429.
6. Caching. Response cache: only routes with `cacheable: true`
   (deterministic task, no tools, no time-dependent content) keyed by
   a hash of model, system, messages and schema; current Claude models
   reject sampling parameters, so cacheability is a route property,
   not `temperature: 0`. Prompt caching: `cache_control` on the system
   block and the tool list for prompts over the model's minimum
   cacheable prefix; assert `cache_read_input_tokens > 0` in a test
   that runs two identical calls.
7. Accounting and observability. Every call writes one record: tenant,
   feature, model from the response, tier, input, output, cache read
   and cache write tokens, cost in USD from the price table in
   `routing.yaml`, latency, status, `stop_reason`, `request_id`. To
   ClickHouse `llm_calls` when the repo has it, else a structured log
   line. One span per call with the GenAI attributes
   (`gen_ai.operation.name`, `gen_ai.provider.name`,
   `gen_ai.request.model`, `gen_ai.response.model`,
   `gen_ai.usage.input_tokens`, `gen_ai.usage.output_tokens`) plus
   `llm.cache_read_tokens` and `llm.feature`; the meter carries
   `llm_calls_total`, `llm_cost_usd_total`, `llm_fallback_total`,
   `llm_request_duration_seconds`. Logs never carry prompt or completion
   bodies unless `LOG_LLM_BODIES=1`, and then through the redactor
   (emails, phone numbers, keys) before write.
8. Fallbacks and kill switch. On 529 or 429 after retries, or a
   `refusal` stop reason: the route's `fallback` (a smaller model, or
   the cached answer when one exists), counted in `llm_fallback_total`
   with a `reason` label. `enabled: false` on a route, or
   `LLM_KILL_<FEATURE>=1` in the environment, returns
   `FeatureDisabled` before any network call. The edge maps it to a
   clear user message.
9. Tests on a recorded-response fake: `FakeProvider` replays fixtures
   from `tests/llm/recordings/<feature>/<hash>.json`; `RECORD_LLM=1`
   records against the real API on a laptop, never in CI. Tests cover:
   routing picks the tier, retry on 529 then success, no retry on 400,
   idempotent replay, rate limit, kill switch, fallback counted, cost
   computed from usage, bodies absent from logs by default.
10. Runtime access. A Claude Code subscription pays for building, not for
    the product's own calls: those need a key per provider in the
    environment (`.env.example` lists the names, never values). Run
    `python3 "${CLAUDE_PLUGIN_ROOT}/skills/llm-gateway/scripts/llm_access_check.py" --routing llm/routing.yaml`
    (add `--live` on a machine with network and ssl; for OpenRouter it
    also prints the credit left on the key). Copy its `llm-access:` line.
    For a repeatable check, copy the script into the repo as
    `scripts/llm_access_check.py` and point any make target at that copy;
    a target that names the kit's own path breaks on every other machine.
    A missing provider is reported under Not done with the variable to
    set; it is not faked with a stub in production code.
11. Migrate every call site found in step 2 to the gateway. Re-run the
    call-site gate from step 2; now it is the gate: it must exit 0 (zero
    outside `llm/`, at least the gateway's own provider call inside).
    Fix what it lists and rerun. Report.

## Output contract

```
## LLM gateway: <repo> (<stack>)
call sites before: <llm_callsites_check.py counts line from step 2, verbatim> (<paths>)
call sites after: <llm_callsites_check.py counts line from step 10, verbatim>
routes configured: <R> (fast <a>, balanced <b>, deep <c>), fallbacks <f>, disabled <d>
resilience: retries sdk 2 + 529 x1, idempotency 24h, timeouts per route, rate limit per tenant
caching: response cache on <k> routes, prompt cache verified (cache_read_input_tokens > 0: yes | not run)
accounting: <clickhouse llm_calls | structured log>, spans with gen_ai.* attributes
kill switch: LLM_KILL_<FEATURE>, routing.yaml enabled
tests: <T> on FakeProvider, recordings <n>
access: <llm_access_check.py llm-access line, verbatim>
```

## Gotchas

- Read `stop_reason` before `content`. `refusal` and `max_tokens`
  arrive as HTTP 200 and look like a short answer.
- Take `model` and cost from the response, not the config. A provider
  fallback or a canary route that did not take is invisible otherwise.
- Prompt cache is a prefix match. A timestamp or request id in the
  system prompt makes every call a cache write at 1.25x.
- Idempotency keys are per tenant; one key from two tenants is two requests.
- Thinking is on by default on Opus 5 and Fable 5.1; `budget_tokens`
  and sampling parameters return 400. Control depth with
  `output_config.effort`, per route.
- Streaming is required above about 16K `max_tokens`; the route decides it.
- A demo that works on the developer's machine and fails on the day is
  almost always a key: the laptop had `ANTHROPIC_API_KEY` from another
  project. Run the access check in the environment that will serve.
- Never log bodies in production by default. `LOG_LLM_BODIES` is a
  debugging toggle with a redactor in front, not a feature.
- The kill switch is checked before the rate limiter and before the
  cache. A disabled feature spends nothing.
