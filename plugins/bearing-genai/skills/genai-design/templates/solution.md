# GenAI solution: <title>

<!-- Template guidance: every section below carries a comment saying what goes
     there (What), what a strong entry has (Good) and a one-line example
     (Example). Delete each comment when you fill its section. This document
     is the contract between the problem and the build: one metric, one
     approach, one model tier and the cheaper approach rejected on paper.
     The ADR and the HLD are written from it. Every number not measured is
     prefixed "assumption:" so the eval can replace it. -->

Serves: REQ-nnn, US-nn-nnn, <PREFIX>-<n>
Status: Draft | Reviewed
Owner: <name>
ADR: docs/adr/NNNN-<kebab>.md
HLD: docs/design/<kebab>-hld.md

## 1. Problem

<!-- What: the problem in one line, as the user or the business feels it.
     Good: names who has the problem and what it costs today; no solution
     words ("agent", "RAG") in the line.
     Example: "Support agents spend about 6 minutes per refund ticket
     finding the order, the policy clause and the refund amount." -->

## 2. Success metric

<!-- What: one line with a number and how it is measured.
     Good: a threshold on a named set ("on the golden set"), not "better
     answers"; a metric without a number is written UNDEFINED and becomes
     an open question with an owner in section 8.
     Example: "Extraction F1 >= 0.92 on the 60-ticket golden set, graded by
     schema check against the agent's final refund record." -->

## 3. Task class

<!-- What: one primary class from the list below; a problem that needs two
     classes is two components, each classified alone.
     Good: the class matches what the model does, not what the product
     does; each component line names one class.
     Example: "extract. Components: order lookup: act with tools; refund
     fields: extract." -->

<generate | extract | classify | converse | retrieve and answer | act with tools | transform>
Components, when more than one: <component: class>

## 4. Approach

<!-- What: the rung chosen from references/decision-tree.md, the reasons in
     order of weight, and the cheaper rung rejected.
     Good: the ladder is walked from the bottom (prompt only first, even for
     an obvious agent); the rejection names the failure on the metric. No
     named failure means the cheaper rung is the answer.
     Example: "Rejected: prompt only, because 38 percent of tickets need the
     order record, which the model cannot know." -->

Chosen: <prompt only | prompt plus retrieval | structured output | single agent with tools | multi-agent | fine-tune>

Reasons, in order of weight:
1.
2.

Rejected: <the cheaper rung>, because <the named failure on the metric>.

## 5. Model and budget

<!-- What: the exact model id, the token budget per request, calls per
     user action, cost per 1,000 requests, p95 latency and the cache plan.
     Good: ids and prices come from the claude-api skill, never memory;
     agents multiply by calls per action (five to twenty is normal); p95
     from a token budget is "assumption:" until the gateway measures it;
     the smaller-model line says why it is right or wrong for this task.
     Example: "Tokens in per request | 3,400 (system 900, tools 600,
     context 1,500, input 400)" -->

| Item | Value |
| --- | --- |
| Model | `<exact id>` |
| Effort | low / medium / high |
| Tokens in per request | N (system N, tools N, context N, input N) |
| Tokens out per request | N |
| Calls per user action | N |
| Cost per 1,000 requests | $N.NN |
| p95 latency | N s (assumption: <how derived>) |
| Cache strategy | <stable prefix, what is cached> |

Smaller model considered: `<id>`; <right because ... | wrong because ...>.

## 6. Risks

<!-- What: the five standing risks below plus the ones specific to this
     problem, each with likelihood, impact, mitigation and the skill that
     builds it (llm-guardrails, llm-gateway, llm-eval, prompt-registry).
     Good: every risk has a mitigation; risks and mitigated risks are equal
     or the gap is an open question in section 8.
     Example: "prompt injection | M | H | ticket text wrapped as untrusted
     data, refund tool needs a human approve step | llm-guardrails" -->

| Risk | Likelihood | Impact | Mitigation | Skill |
| --- | --- | --- | --- | --- |
| hallucination | | | | `llm-guardrails`, `llm-eval` |
| prompt injection | | | | `llm-guardrails` |
| PII | | | | `llm-guardrails`, `llm-gateway` |
| cost blow-up | | | | `llm-gateway` |
| latency | | | | `llm-gateway` |

## 7. Evaluation plan

<!-- What: golden set size, where the items come from, how they are graded,
     the threshold and when the eval runs.
     Good: at least 50 items for classify and extract, 100 for retrieve and
     answer, 20 task trajectories for agents; items are real inputs with
     PII removed, never invented; the threshold is the section 2 metric.
     Example: "Golden set size | 60 refund tickets from March 2026, PII
     removed by the support export script" -->

| Item | Value |
| --- | --- |
| Golden set size | N |
| Source of items | <real tickets, logs, documents; PII removed> |
| Grading | exact match / schema check / rubric with `claude-haiku-4-5` as judge |
| Threshold | <tied to the success metric> |
| Runs on | every prompt version, every model change, weekly on production samples |

Built by `llm-eval`.

## 8. Open questions

<!-- What: every question the design could not answer, including an
     UNDEFINED metric and any unmitigated risk.
     Good: each question has an owner (a person or role) and a date it is
     needed by; a question with no owner is not tracked.
     Example: "Can refund amounts over 500 dollars skip human approval? |
     support ops lead | 2026-10-15" -->

| Question | Owner | Needed by |
| --- | --- | --- |
