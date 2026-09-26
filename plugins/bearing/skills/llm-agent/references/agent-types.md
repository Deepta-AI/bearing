# Agent types

Choose the simplest type whose failure modes you can live with. The
cheaper type rejected goes in the ADR with the named failure.

| Type | Shape | Use when | Not when |
| --- | --- | --- | --- |
| `tool-user` | one model, one loop, N tools | the task needs lookups or actions and fits one context | the task has no actions (use a prompt) or needs two specialisms |
| `planner-executor` | one call writes a plan, a loop executes steps | steps are known before starting and a plan is reviewable | steps depend on results of earlier steps (a plain tool-user re-plans for free) |
| `router` | a classify step, then dispatch to a prompt or agent | several distinct tasks share one entry point | the classes overlap (the router will guess) |
| `supervisor` | a coordinator delegates to specialists, merges results | specialisms need different prompts, tools or models | one context can hold the task (a supervisor triples the cost) |
| `workflow` | a deterministic graph with model steps | regulated or audited flows; every step must be replayable | the path is not known in advance |
| `background` | batch or scheduled, no human present | volume work that can wait; nightly jobs | any step is irreversible (nobody is there to approve) |
| `human-in-the-loop` | a loop with approval gates on tiers | actions change money, data or messages | the gate would fire on every turn (fix the tool surface first) |

## Per type: failure modes, cost profile, effort

### tool-user
- Fails by looping on a failing tool, or by answering without calling
  the tool it should have. Bound turns; make tool errors informative.
- Cost: 3 to 8 calls per action. Effort `medium`; `high` when the
  tools return long results that need reasoning.
- Build: SDK tool runner (`client.beta.messages.tool_runner` /
  `toolRunner`), strict tools, one system prompt from `prompt-registry`.

### planner-executor
- Fails by executing a stale plan after a step changed the world.
  Re-plan when a step returns something the plan did not expect.
- Cost: 1 plan call (Opus 5 or Fable 5.1) plus N step calls (Sonnet 5).
- Build: plan as structured output (`output_config.format`), steps as
  tool-user runs with the step as the task.

### router
- Fails on ambiguous inputs and on classes nobody trained. Add an
  `other` class that escalates; measure confusion per pair in the eval.
- Cost: one cheap call (`claude-haiku-4-5`, `max_tokens` about 256,
  structured output with an enum) plus the target's cost.
- Build: a classify prompt with an enum schema, a dispatch table in
  code, never a model choosing the code path free-form.

### supervisor
- Fails by specialists disagreeing and the coordinator averaging, or
  by unbounded delegation depth. Cap depth at 2; the coordinator
  merges by a rule, not by a vibe.
- Cost: 3 to 10 times a tool-user. Coordinator on Opus 5 or Fable 5.1,
  specialists on Sonnet 5 where the eval allows.
- Build: specialists are tool-user agents exposed to the coordinator as
  tools with their own tier (the highest tier of their tools).

### workflow
- Fails silently when a model step returns a shape the next step did
  not expect. Every model step is structured output with a schema, and
  every edge is a code check.
- Cost: predictable; the graph decides the number of calls.
- Build: a plain state machine in code with model steps as functions,
  a manual loop where a step uses tools. LangGraph is an option when
  the graph has many branches and needs checkpoints; say why in the
  ADR, because it adds a runtime, a tracing story and an upgrade path.

### background
- Fails at 3 a.m. with nobody watching: partial batches, retries that
  double-charge, an input that makes every item fail. Idempotent
  writes, a dead-letter list, a cost cap per run.
- Cost: use the Batches API at half price when latency does not
  matter; Managed Agents with scheduled deployments when the job needs
  a sandbox and a cron; otherwise a systemd timer around a tool-user.
- Build: no `irreversible` tools at all; `write` tools idempotent by
  key; a summary written per run.

### human-in-the-loop
- Fails by approval fatigue (every turn asks) or by a gate that a
  prompt injection can talk around. The gate is code on the tier, not
  a question the model decides to ask.
- Cost: as tool-user plus waiting time; the run is suspended, not
  polling. Persist the pending tool call and resume on approval.
- Build: gate inside the tool handler (return "approval required" and
  a token) or inspect pending `tool_use` blocks in the runner loop and
  override with `set_messages_params` / `setMessagesParams`.

## Choosing where to run it

| Need | Run it as |
| --- | --- |
| domain tools, your infrastructure, request path | SDK tool runner in the service |
| file, shell, grep and web tools on your infrastructure | Claude Agent SDK (`claude-agent-sdk`, `@anthropic-ai/claude-agent-sdk`) |
| hosted loop and sandbox, scheduled, versioned config | Managed Agents (`client.beta.agents`, sessions) |
| Go service needs an agent | a Python or TypeScript agent service behind HTTP; Go does not host the loop |

## Bounds every type carries

`max_turns` (10 for tool-user, 30 for supervisor), `max_cost_usd`
(from `usage.input_tokens`, `output_tokens`, `cache_read_input_tokens`
and the price table), per-call `timeout` (60 s; 600 s for Fable 5.1
with streaming), wall-clock limit, kill switch checked before every
model call, and a `refusal` stop reason that ends the run.
