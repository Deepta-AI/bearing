---
name: llm-guardrails
description: 'Secures an LLM feature or agent: prompt injection and jailbreak defence, PII checks, a tool-call permission gate, output checks, adversarial tests. Use when asked for "guardrails" or about "prompt injection".'
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
  the module exports `CHECKS` and `POLICY` in the shape it names. Checks
  that only run inside the feature's entry point (a guard after the
  model call) are tested through that entry point with a scripted model
  that obeys each attack, instead of a `CHECKS` map.

## Steps

1. Scope from `$ARGUMENTS`: one feature or the whole service. Stack
   from `$2` or from `pyproject.toml` versus `package.json`. Load the
   `claude-api` skill before writing any classifier call. Find every
   model call (`messages.create`, `messages.parse`, `tool_runner`,
   `toolRunner`, `messages.stream`, or the repo's own client wrapper)
   and every tool registry; count the call sites. Zero call sites: ask
   once where the model will be called, then build ahead of it and say
   so in the report. Read the repo's own risk documents (security
   review, policy, README volume) before designing: every number and
   rule the guardrails enforce comes from them where they state one.
2. Policy: `guardrails/policy.yaml` from `templates/policy.yaml`. Each
   limit cites its source line: a review that says extracts never
   exceed 20,000 characters sets 20,000, not a round number of your
   own. Invent a value only where no document gives one, and name it
   as an assumption. Fill the PII classes in scope (Indian PAN,
   Aadhaar, phone, email, card and account numbers, plus the
   product's own), the tool tiers and irreversible actions, the output
   schema, the fixed responses the policy dictates word for word, and
   the classes only a classifier can decide.
3. Minimise first: before any detector, cut the prompt to what the
   task needs. Other people's records, and facts derived from them (a
   slot marked taken by another patient), stay out; pass the computed
   answer (free slots), not the data it came from. The caller's own
   records stay in, so the feature can still answer about them.
4. Input checks, one module (`app/guardrails/` or `src/guardrails/`),
   run on every turn, not only the first:
   - size against the policy limit, refused before any model call;
   - fixed-response rules (emergencies, legal notices) on normalised
     text, before the model, matching the policy's categories in
     paraphrase ("I passed out", "can't breathe properly") without
     firing on a keyword alone ("my chest X-ray report is ready");
   - PII redaction (skip it, with the reason in the policy, when the
     feature takes no personal data and stores nothing: a public Q&A
     over published content; a classifier likewise only where a class
     needs one) in every common format (spaced, hyphenated,
     unbroken; checksum where the class has one), applied to the text
     stored in history too, so a later turn never resends it; times,
     fees, dates and slot numbers in the same message pass unchanged;
   - delimiters: document text inside a tag, with any closing or
     opening tag inside the text escaped, so the data block cannot be
     closed from inside;
   - injection patterns as a counted signal, not the defence.
   Decide what a hit costs before choosing to block: in a chat turn a
   block is one refusal; on a document the business must process (an
   invoice, a claim, a CV) a block drops real work, so a hit routes to
   a person with the extraction attached. Gate languages only when the
   product names them; a legitimate bilingual document is a control.
5. Tool-call checks, in code around every tool:
   - an unknown tool name or arguments failing the tool's schema is
     denied, logged with a reason code, and tested;
   - a side effect's target (email recipient, account, path, customer
     id) comes from the trusted record of the one entity in scope,
     never from the model's arguments or the document. Identify that
     entity once, from a field the record owns (a GSTIN that matches
     exactly one master entry); a document naming two known entities
     is ambiguous and gets no side effect. An allowlist built from
     every entity a document mentions lets the document pick;
   - a side effect's content is built from trusted fields (a template:
     invoice number, missing field names), or screened for other
     records, account numbers, URLs and addresses; a free-text body
     the model wrote is an exfiltration channel even to a correct
     recipient;
   - the loop is bounded: model turns per request and side effects per
     entity (one email per invoice), and hitting the bound ends in a
     non-accepted result, not an exception;
   - a value the model read that differs from the trusted record (a
     new bank account) never writes the record; it routes to a person.
   A feature with no tools gets no tool gate; say so.
6. Output checks:
   - schema validation before anything downstream, including
     `stop_reason` `max_tokens` and `refusal`, malformed JSON and
     missing fields, all ending in a handled non-accepted result;
   - business invariants the schema cannot see, computed from the
     source: the extracted total equals the document's grand total
     (not merely some amount in it, and not the subtotal), the entity
     exists in the master, a value that differs from the record goes
     to a person;
   - leak scan relative to the caller: other people's identifiers
     matched by parts (first name alone, surname, phone digits with
     separators stripped), not only the exact full string; the
     signed-in user's own details are not a leak;
   - policy classes (medical, legal, financial advice) by the forms
     the policy forbids, not by a list of drug names: what a symptom
     might mean, home treatment ("rest, drink water, put ice on it"),
     a medicine, a dose, reading a report. A reply that mentions a
     symptom to book it ("the dermatologist can see the rash at
     16:30") is not advice. What a deterministic check cannot decide
     goes to a classifier on `claude-haiku-4-5` with an enum schema
     and `max_tokens` about 256, costed per request at the stated
     volume in the report; or fails closed to the policy's safe reply,
     and the report names the choice;
   - grounding for RAG answers (every claim sentence maps to a
     retrieved chunk above the threshold, else marked ungrounded).
7. Wire through one path: `check_input` before the call, `gate_tool`
   around every tool, `check_output` after; no call site reaches the
   model around it. Logs carry `request_id`, `check`, `verdict`,
   `reason`, never content: not the prompt, the document, the user's
   message, the model's reply, nor any free text the model authored
   (a review reason, an email body). Counters per check and reason;
   alert on a rate change, not a single block.
8. Tests, offline, with the repo's scripted model. The proof is the
   feature's public entry point, not the detector: every check gets at
   least one test that runs `process()` or `reply()` and asserts on
   what the scripted model received (the captured request), what the
   caller got back, and the side effects (mail sent, queue, record).
   A detector-level fixture that passes proves the regex, not the
   wiring or the limit. Required beyond that:
   - the crafted attack the user supplied, twice: once as is, and once
     with the input screen bypassed and a scripted model that obeys it
     (calls the tool, returns the poisoned JSON), so the downstream
     gates are proven on the real attack;
   - at least eight distinct attack inputs through the full path
     (direct override, fake system message, closing-tag escape,
     encoded instruction, authority claim, tool-target swap to another
     known entity, PII request, off-policy reply), one of them on a
     later turn of a conversation;
   - controls through the same path that must come back byte-equal to
     the scripted reply or accepted: the product's ordinary requests,
     ones mentioning money, dates, symptoms and names, the existing
     fixture's own examples, and for every "other people's data is
     removed" rule a second signed-in owner (not the default fixture
     user) who still gets their own data;
   - the fixture set from `references/adversarial-set.md` with the
     counts test from `templates/test-guardrails.md`, which prints the
     `guardrails:` line and fails on zero checks or fixtures; copy the
     line from the run.
   Existing tests change only additively. When one cannot pass under
   the new rule (a placeholder input naming no entity), change its
   input to a real sample, keep its assertion, and name the change.
9. `--audit`: report only. Call sites without `check_input` or
   `check_output`, tools without a tier, policy keys with no fixture.
10. Report: the output contract, then for each deterministic check its
   match rule and one concrete input it misses (a first name the scan
   does not know, advice phrased without a trigger word). Never claim
   injection is prevented or that a check was measured against a real
   model when only a scripted one ran. Record the block and redact
   decisions as an ADR (`adr`) when the repo keeps them.

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
- A green detector test with the wrong limit is a false pass. Check
  every number in the policy against the document it came from.
- "Not a leak for this user" needs a second user. A test that only
  signs in the default fixture patient never shows the filter keeps
  someone else's own records.
- Attacks that arrive on turn three are the ones a first-turn screen
  misses; state (history, redacted text, counters) is part of the
  attack surface.
