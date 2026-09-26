---
name: llm-guardrails
description: 'Adds guardrails to an LLM feature: prompt injection and PII checks before the model, a tool-call permission gate, output checks, adversarial tests. Use when asked for "guardrails", "prompt injection" or "PII in prompts".'
argument-hint: "[feature name] [python|typescript] [--audit]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(ls:*), Bash(mkdir:*), Bash(uv run pytest:*), Bash(npm test:*), Bash(make:*)
---

# llm-guardrails

A guardrail is code that runs before and after the model and decides in
the policy's terms, not the model's. The policy is a file people can
review; the checks are one module the gateway calls; the proof is a set
of adversarial fixtures that every check must catch, counted on every
run. A check that exists in the prompt only ("do not reveal the system
prompt") is a request, not a guardrail.

## Inputs

- Call sites: the grep in step 1; if it finds none, asks where the model
  is or will be called, and builds the module ahead of the first call
  with the fixtures as the proof.
- Policy facts: `docs/genai/<name>-solution.md` for the task, the PII
  classes and the risks; if absent, asks the task, the scale and the
  model tier in one question.
- Stack: `$2`, else `pyproject.toml` versus `package.json`; neither:
  asks.
- Gateway: `llm/` from `llm-gateway`; if absent, the module wraps
  each call site directly (one wrapper function) and the gateway is a
  follow-up, not a prerequisite.
- Tool registry: `llm-agent`'s; if absent, the tool-call checks run
  against the policy's own tier table.
- Fixture test: `templates/test-guardrails.md` (Python and TypeScript);
  the module exports `CHECKS` and `POLICY` in the shape it names.

## Steps

1. Scope from `$ARGUMENTS`: one feature or the whole service. Stack
   from `$2` or from `pyproject.toml` versus `package.json`. Load the
   `claude-api` skill before writing the classifier call. Find every
   model call (`messages.create`, `messages.parse`, `tool_runner`,
   `toolRunner`, `messages.stream`) and every tool registry; count the
   call sites. Zero call sites: ask once where the model will be called,
   then build ahead of it and say so in the report.
2. Policy: `guardrails/policy.yaml` from `templates/policy.yaml`. Fill
   the limits (max input chars, max output tokens, allowed languages),
   the PII classes in scope (Indian PAN, Aadhaar, phone, email, card
   and account numbers, plus the product's own), the injection
   patterns, the tool tiers and the denylist of irreversible actions,
   the output schema names, the policy classes for the classifier, and
   the grounding threshold for RAG answers.
3. Input checks in the module (`app/guardrails/` or `src/guardrails/`),
   in this order: size, language, PII detect and redact (regex for the
   structured classes, placeholders like `[PAN_1]` with a reversible map
   kept out of the prompt), injection patterns on the raw text, and
   delimiter enforcement (a closing tag inside a variable is escaped).
   The result is `allowed | redacted | blocked` with a reason code.
   Decide what a hit costs before choosing `blocked`: in a chat turn a
   block is one refusal; on a document the business must process (an
   invoice, a claim, a CV) a block drops real work, so a pattern hit
   there routes to a person with the extraction attached and is
   counted. Gate languages only when the product names them; a
   legitimate bilingual document is a control case, not an attack.
4. Tool-call checks: the permission tier gate (`read` passes, `write`
   validates arguments against the policy's bounds and denylist,
   `irreversible` requires an approval token or is denied), argument
   validation against the tool's schema again, and a denylist match on
   argument values (paths, ids, amounts above a limit). Targets of a
   side effect (email recipient, account, file path, customer id) are
   taken from the trusted record for the one entity in scope, never
   from anything the model read: an allowlist built from every entity
   a document mentions lets the document pick the target. An unknown
   tool name or failing arguments is denied, logged and tested. Bound
   the tool loop (turns per request, side effects per entity) so a
   model that keeps calling a tool cannot loop or send twice. A
   feature with no tools gets no tool gate; say so in the report.
5. Output checks: schema validation when the caller parses the
   output, plus the business invariants the schema cannot see (the
   extracted amount appears in the source, the entity exists in the
   master, a value that differs from the trusted record goes to a
   person); PII leak scan (same detectors as input, on the output),
   relative to the caller: the signed-in user's own details are not a
   leak; policy classifier on `claude-haiku-4-5` with an enum schema
   over the policy classes, `max_tokens` about 256, only for classes
   a deterministic check cannot decide, and its per-request cost and
   latency at the stated volume go in the report; citation grounding for
   RAG answers (every claim sentence maps to a retrieved chunk above
   the threshold, else the answer is marked ungrounded); refusal
   handling (`stop_reason == "refusal"` and the prompt's `unsupported`
   status become one user-facing message and a metric).
6. Wire at the gateway when present, else at each call site through
   one wrapper: `check_input` before the call, `gate_tool` around every
   tool, `check_output` after. No call site reaches the model around
   the module. Every decision
   logs `request_id`, `check`, `verdict`, `reason`, never the content.
7. Metrics: counters `guardrail_blocked_total{check, reason}`,
   `guardrail_redacted_total{class}`, `guardrail_output_flagged_total
   {check}`, and a histogram for the classifier latency. Alert on a
   block rate change, not on a single block.
8. Minimise first: before any detector, cut the prompt to what the
   task needs. Other people's records, and facts derived from them (a
   slot marked taken by another patient), stay out; pass the computed
   answer (free slots), not the data it came from. The caller's own
   records stay in, so the feature can still answer about them.
9. Tests: fixtures from `references/adversarial-set.md` in
   `tests/guardrails/fixtures.jsonl` (id, check, input, expected
   verdict), and the fixture test from `templates/test-guardrails.md`:
   a parametrised case per fixture plus a counts test that prints the
   `guardrails:` line (checks configured, fixtures, passing, policy
   keys without a fixture) and fails on zero checks, zero fixtures, a
   failing fixture or an unexercised policy key. Run it with the
   granted command (`uv run pytest -s tests/guardrails`, `npm test`,
   or the `make` target) and copy the line; nobody counts by hand. The
   fixtures also belong in the eval set (`llm-eval`) so a model
   change re-runs them; without an eval, this test is the gate. Three
   tests beyond the fixtures: at least eight distinct attack inputs
   (direct override, fake system message, closing-tag escape, encoded
   instruction, instruction in a document, tool-target swap, PII
   request, off-policy advice) run through the full path, each asserting
   on the reply text, not only the verdict; the crafted attack the
   user supplied also runs with the input screen letting it through
   (a scripted model that obeys it), so the downstream gates are
   proven on the real attack and not on a paraphrase; a benign set
   (the product's ordinary requests and replies, including ones that
   mention money, dates, names and symptoms, and the caller's own
   details) through the same path that must come back
   unchanged, so over-blocking is measured; and existing tests changed
   only additively, with any unavoidable change named in the report.
10. `--audit`: report only. Call sites without `check_input` or
   `check_output`, tools without a tier, policy keys with no fixture.
11. Record the policy decisions (what is blocked, what is redacted) as
    an ADR (`adr`, or a file in `docs/adr/`); HLD section when an
    HLD exists. Print the output contract.

## Output contract

```
## Guardrails: <scope> (<python | typescript>)
policy: guardrails/policy.yaml   module: <path>   wired at: <gateway path>
call sites: N (guarded: N)   tools: N (tiered: N)
fixtures: <guardrails counts line from the fixture test, verbatim>
classifier: claude-haiku-4-5, classes N, p95 N ms (assumption | measured)
metrics: guardrail_blocked_total, guardrail_redacted_total, guardrail_output_flagged_total
audit: N unguarded call sites, N untiered tools, N policy keys without a fixture
```

## Gotchas

- Redact before the model, not after. PII that reached the prompt is
  in the provider's logs and in the cache.
- Injection pattern lists catch yesterday's attacks. The delimiter rule
  and the tool tier gate catch tomorrow's; the patterns are the metric,
  the gates are the defence.
- A classifier on the same model that wrote the output grades its own
  work. Use `claude-haiku-4-5` with an enum schema, and keep the
  classes few.
- Grounding by string overlap passes paraphrase and fails synonyms.
  Score with embeddings or a small-model judge, and set the threshold
  from the eval set, not by feel.
- Do not block on the classifier for a streaming answer at every
  token. Check the final answer; stream only when the policy allows a
  post-hoc retraction.
- Refusals are a product path. Log them, count them, and show the
  user one honest sentence; never retry silently with a looser prompt.
- Fixtures are data. A fixture that mentions a real person or a real
  account number is itself a PII leak; synthesise them.
