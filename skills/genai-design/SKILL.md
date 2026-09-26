---
name: genai-design
description: 'Designs a GenAI solution before code: success metric, approach with the cheaper option rejected, model tier, cost, latency, risks, eval plan. Use when asked "how should we build this with an LLM" or "RAG or agent".'
argument-hint: "<title> [path to PRD, problem statement or notes]"
allowed-tools: Read, Write, Grep, Glob, Skill, Bash(ls:*), Bash(mkdir:*), Bash(git branch:*)
---

# genai-design

The solution document is the contract between the problem and the build.
It names one metric, one approach, one model tier, and the cheaper
approach that was tried on paper and rejected. Every number that was not
measured is prefixed "assumption:" so the eval can replace it. The
decision goes to an ADR, the design goes to the HLD; this document is
the reasoning that feeds both.

## Inputs

- Problem statement: looks in the path in `$ARGUMENTS`, then
  `docs/product/PRD.md` and `docs/stories/`; if absent, asks the user to
  paste one paragraph and works from that alone.
- Prior decisions: looks in `docs/adr/`; if absent, the Decisions-first
  step records them fresh.
- Model ids and prices: the `claude-api` skill; if it is not installed,
  asks the user for the model id and price and marks each number
  "assumption:".
- Nothing else. No PRD, no stories and no scaffold are needed.

## Steps

**Decisions first.** Before building, run `tech-decision` for the keys llm
provider and models, vector store and embeddings. `tech-decision` asks only about the keys this task needs that no
accepted ADR, the request or the code already settles, one question at
a time, and records only what the user decides; a key still
awaiting an answer follows
${CLAUDE_PLUGIN_ROOT}/skills/tech-decision/references/decision-protocol.md.

1. Title from `$ARGUMENTS`. Inputs from the path given, else
   `docs/product/PRD.md`, `docs/stories/` and `docs/adr/`. Collect the
   ids served (`REQ-nnn`, `US-nn-nnn`, `<PREFIX>-<n>`) and count the
   requirements read. Zero requirements: ask for a one-paragraph problem
   statement, record the ids as `none`, and continue from it. Load the `claude-api` skill for the current model ids and
   prices; never quote a price or an id from memory.
2. Restate. Problem in one line. Success metric in one line with a
   number and how it is measured (for example "extraction F1 >= 0.92 on
   the golden set"). A metric without a number is written `UNDEFINED`
   and becomes an open question with an owner.
3. Classify the task: generate, extract, classify, converse, retrieve
   and answer, act with tools, transform. One primary class. A problem
   that needs two classes is two components, each classified alone.
4. Choose the approach with `references/decision-tree.md`: prompt only,
   prompt plus retrieval, structured output, single agent with tools,
   multi-agent, fine-tune. Walk the ladder from the bottom. Record the
   reasons for the step chosen and the cheaper step rejected, with the
   named failure that ruled it out. No named failure: the cheaper step
   is the answer.
5. Model tier and budget from the tier table in the reference. Write
   the token budget per request (system, retrieved context, user input,
   output), the cost per 1,000 requests, and the p95 latency estimate
   from the output tokens and the tier's output rate. Multiply by calls
   per user action for agents. Say when a smaller model is right
   (classification, routing, extraction with a schema, first-pass
   filters) and when it is not (multi-step reasoning, long context with
   many constraints, anything the metric shows the smaller model fails).
   Then runtime access: which account pays for the product's calls (an
   API key per provider, or one OpenRouter key with a spend limit), the
   monthly cap from expected volume, and any GPU the approach needs. A
   Claude Code subscription covers building, not the product's calls.
6. Risks: hallucination, prompt injection, PII, cost blow-up, latency,
   plus the specific ones for this problem. Each risk names its
   mitigation and the skill that builds it: `llm-guardrails`,
   `llm-gateway`, `llm-eval`, `prompt-registry`. Count risks and
   mitigated risks; they must be equal or the gap is an open question.
7. Evaluation plan: golden set size (at least 50 items for classify and
   extract, 100 for retrieve and answer, 20 task trajectories for
   agents), source of the items (real inputs, never invented), grading
   method (exact match, schema check, rubric with a judge model), and
   the acceptance threshold tied to the success metric. Hand the build
   of the set to `llm-eval`.
8. Write `docs/genai/<kebab>-solution.md` from `templates/solution.md`.
   Write the ADR stub for the approach decision (`adr`, or a file
   in `docs/adr/` in the same shape; status Proposed) and name the HLD
   `high-level-design` can write later. List open questions
   with owners.
9. Print the output contract.

## Output contract

```
## GenAI solution: docs/genai/<kebab>-solution.md
Problem: <one line>
Metric:  <one line with a number> | UNDEFINED
Task: <class>   Approach: <approach>   Rejected: <cheaper approach> (<failure>)
Model: <exact id>   Tokens/request: in N, out N   Calls/action: N
Cost/1,000 requests: $N.NN   p95: N s (assumption | measured)
Runtime: <provider key or OpenRouter key>, cap $N/month, GPU <none | type>
Requirements read: N   Risks: N (mitigated: N)   Open questions: N
Golden set: N items from <source>, graded by <method>, threshold <value>
ADR: docs/adr/NNNN-<kebab>.md (Proposed)   HLD: docs/design/<kebab>-hld.md (to write)
```

## Gotchas

- A solution without a rejected cheaper approach is a preference, not a
  design. Try prompt only on paper first, even for an obvious agent.
- Cost per request is not the bill. An agent loop makes five to twenty
  model calls per user action; the estimate multiplies by that number.
- Latency from a token budget is an assumption. Label it so, and let the
  gateway's measured p95 replace it after the first week.
- Fine-tune is the last rung. It needs a labelled set of thousands and a
  measured prompt failure; neither exists at design time.
- Write exact model ids from the `claude-api` skill. "Sonnet" or "the
  small model" cannot be priced or reproduced.
- A golden set of invented examples measures the inventor. Take the
  items from real tickets, logs or documents, with PII removed.
- No em dashes in the document.
