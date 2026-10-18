# Decision tree for a GenAI solution

Walk the ladder from the bottom. Each step up costs more to build, run
and test. Move up only when the step below has a named failure on the
success metric, not a feeling.

## Task classes

| Class | What the model does | Usual approach | Usual model |
| --- | --- | --- | --- |
| classify | picks one of N labels | prompt only, structured output | Haiku 4.5, Sonnet 5 when nuance matters |
| extract | fills a schema from text or images | structured output | Sonnet 5; Haiku 4.5 for flat schemas |
| transform | rewrites, translates, summarises, formats | prompt only | Sonnet 5; Opus 5 for long or careful edits |
| generate | writes new content from a brief | prompt only, then retrieval when facts matter | Opus 5; Sonnet 5 for volume |
| retrieve and answer | answers from a corpus with citations | prompt plus retrieval | Sonnet 5; Opus 5 for multi-document synthesis |
| converse | multi-turn with state | prompt only or plus retrieval, memory rules | Sonnet 5; Opus 5 for high-stakes support |
| act with tools | reads and changes systems | single agent with tools; workflow when regulated | Opus 5; Fable 5.1 for long-horizon work |

## The ladder

1. Prompt only. One call, one prompt from `prompt-registry`. Stops here when
   the golden set passes the threshold.
   Fails when: the answer needs facts the model cannot know, the output
   must be machine-parsed, or the task needs actions.
2. Prompt plus retrieval. The prompt carries chunks fetched per
   request. Needs a corpus, a chunking rule, an embedding or lexical
   index, and citation grounding in `llm-guardrails`.
   Fails when: the corpus changes faster than the index, the answer
   needs more than reading (calculation, lookups in live systems).
3. Structured output. `output_config.format` with a JSON schema, or
   `messages.parse` with a Pydantic model or a Zod schema. Combine with
   1 or 2. Not a rung above them; a shape for their output.
   Fails when: the schema needs data the model must go and fetch.
4. Single agent with tools. One model in a bounded loop with a typed
   tool registry (`llm-agent tool-user`). Needs permission tiers, a
   cost cap, trajectories in the eval set.
   Fails when: one context cannot hold the task, or two specialisms
   need different prompts and tools.
5. Multi-agent. A supervisor with specialists (`llm-agent supervisor`),
   or a planner and executor. Costs three to ten times a single agent
   per action. Needs the single agent to have failed on a measured
   trajectory set.
6. Fine-tune. Only with thousands of labelled examples, a measured
   prompt ceiling on the golden set, and a plan to re-train when the
   data drifts. Not offered for the current Claude models through the
   API; a fine-tune decision is a platform decision and needs an ADR.

## Questions that move you up or down

- Can a person with the prompt and no tools do the task? Yes: rung 1.
- Does the answer depend on documents the user cannot paste? Rung 2.
- Will code read the answer? Add rung 3.
- Must the model change something, or look something up live? Rung 4.
- Does the task need more than one system prompt to describe? Rung 5.
- Does the task run without a human present? A `background` agent
  with no irreversible tools, or a batch job over the Batches API at
  half price.
- Is the flow regulated or audited step by step? A `workflow` agent:
  a deterministic graph with model steps, not a free loop.

## Model tiers (prices from the claude-api skill, per 1M tokens)

| Tier | Id | Input | Output | Use for |
| --- | --- | --- | --- | --- |
| hardest reasoning | `claude-fable-5-1` | $10 | $50 | long-horizon agents, hard synthesis, work a wrong answer makes expensive |
| strong general | `claude-opus-5` | $5 | $25 | the default for generate, converse, act with tools |
| volume | `claude-sonnet-5` | $2 | $10 | extract, transform, retrieve and answer at scale |
| cheap classification | `claude-haiku-4-5` | $1 | $5 | routing, labels, first-pass filters, judges for simple rubrics |

Rules that go with the table:

- Thinking is adaptive on Fable 5.1, Opus 5 and Sonnet 5; depth is set
  with `output_config.effort` (`low` to `max`). Haiku 4.5 still uses
  `thinking: {type: "enabled", budget_tokens: N}`.
- Fable 5.1 turns can run for minutes on hard tasks. Stream, and plan
  the timeout and the progress UX before choosing it.
- Fable 5.1 rejects forced `tool_choice` (`any`, `tool`) and
  `temperature`; design tool use with `auto` and an instruction.
- A smaller model is right when the golden set passes on it. Run the
  set on Haiku 4.5 or Sonnet 5 first; move up only on a measured miss.
- The cheapest strong lever is effort, not a model swap: Opus 5 at
  `low` often beats a smaller model at `high` and keeps one cache.

## Token budget and cost

```
tokens_in  = system + tools + retrieved context + user input
tokens_out = expected answer (+ thinking, which is billed as output)
cost_per_request = tokens_in * in_price/1e6 + tokens_out * out_price/1e6
cost_per_1000    = cost_per_request * 1000 * calls_per_action
```

Cache reads cost about a tenth of input price; a stable system prompt
and tool list in front of the volatile part earns that. Batch requests
run at half price when the answer can wait an hour.

## Latency

```
p95 = time_to_first_token + tokens_out / output_rate + tool_time * calls
```

Assume, until the gateway measures it: 1 to 2 s to first token; 50 to
80 output tokens per second on Sonnet 5 and Haiku 4.5; 30 to 50 on Opus
5; slower on Fable 5.1 with deep thinking. Write "assumption:" in front
of every number that came from this section.

## Risks and the skill that mitigates each

| Risk | Mitigation | Skill |
| --- | --- | --- |
| hallucination | retrieval with citation grounding, structured output, judge in eval | `llm-guardrails`, `llm-eval` |
| prompt injection | delimiters, input checks, tool permission tiers | `llm-guardrails`, `prompt-registry` |
| PII | redaction before the model, output leak check, no PII in logs | `llm-guardrails`, `llm-gateway` |
| cost blow-up | per-request and per-day caps, max turns, cache, batch | `llm-gateway`, `llm-agent` |
| latency | streaming, smaller model for the hot path, timeouts | `llm-gateway` |
| wrong answers nobody notices | golden set, threshold, eval on every prompt change | `llm-eval` |
