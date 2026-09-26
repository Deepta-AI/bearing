---
name: llm-agent
description: 'Builds an LLM agent on the Anthropic SDK: tiered tool registry, bounded loop, memory, call logging, guardrails, trajectory evals, kill switch. Use when asked to "build an agent", "give the model tools" or "multi-agent".'
argument-hint: "<type> <name> [python|typescript]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(ls:*), Bash(mkdir:*), Bash(uv run pytest:*), Bash(npm test:*), Bash(make:*)
---

# llm-agent

An agent is a model in a loop with tools. What makes it shippable is
everything around the loop: a registry that says what each tool may do,
a bound on turns and money, a log of every call with the request id, a
guard in front of the model, a set of trajectories that prove it works,
and a switch that stops it. The type is chosen first, from the reference,
and the cheaper type is named as rejected in the ADR.

## Inputs

- Task and stories: `docs/genai/<name>-solution.md` and `docs/stories/`;
  if absent, asks the task, the scale (runs per day) and the model tier
  in one question and continues.
- Stack: `$3`, else `pyproject.toml` versus `package.json`; neither: asks.
- Model ids and SDK shapes: the `claude-api` skill; if not installed,
  asks for the model id.
- Gateway: `llm/` from `llm-gateway`; if absent, the agent calls the
  SDK through one `call_model` function that logs the fields in step 6,
  and the gateway is a follow-up.
- Guardrails module: `app/guardrails/` or `src/guardrails/`; if absent,
  the tier gate lives in the registry and the input and output checks
  are a follow-up through `llm-guardrails`.
- Registry, loop and tests come from `templates/`; no scaffold needed.

## Steps

1. Type from `$1`, name from `$2`, stack from `$3` or from
   `pyproject.toml` versus `package.json`. Read
   `references/agent-types.md`; refuse a type not in it. Load the
   `claude-api` skill for the current model ids and SDK shapes; do not
   write a model call from memory. Read the stories the agent serves, or
   the Inputs answers, and write, in one paragraph each: the goal, the stop condition, the
   user who is present (or not), and the actions that cannot be undone.
2. Model: `claude-opus-5` by default; `claude-fable-5-1` for
   long-horizon or hard-reasoning work; `claude-sonnet-5` for a
   `router` or a high-volume `background` agent; `claude-haiku-4-5`
   for the classify step of a router. Thinking adaptive, `effort` per
   type from the reference. Say in the ADR why a smaller model was or
   was not enough.
3. Tool registry from `templates/tool-registry.md`: for every tool a
   name, a description written for a model reader, a strict input
   schema (`additionalProperties: false`, every field required or
   defaulted), a permission tier (`read`, `write`, `irreversible`), a
   timeout, an idempotency flag, and a handler. Write the registry
   test from the same template's Test section; it counts the tools
   sent, the registry entries and those with a schema, prints the
   `agent-tools:` line and fails on zero or a mismatch. Nobody counts
   by hand.
4. Loop from `templates/agent-python.md` or
   `templates/agent-typescript.md`: the SDK tool runner by default, a
   manual loop only for the `workflow` type. Bounds: `max_turns`,
   `max_cost_usd` computed from `usage` per call, a per-call timeout, a
   wall-clock limit. Handle every stop reason: `end_turn`, `tool_use`,
   `max_tokens` (retry once with a larger budget), `pause_turn`
   (resume), `refusal` (log and stop). Kill switch: an environment flag
   read at start and a per-request check of a flag store before each
   model call; a tripped switch ends the run with a logged reason.
5. Memory: conversation window in turns; summarise beyond it with
   server-side compaction or a summariser call; long-term store only
   when a story names it, with an ADR for the store.
6. Logging through the gateway, else `call_model`: every model and tool
   call with request id, agent name, turn, model, tokens in and out, cache
   read tokens, cost, latency, tool name, tier, outcome, error class.
   Never the prompt body or a tool result in the log at info level.
7. Guardrails through the module when present, else the tier gate in
   the registry: input checks before the first call, output checks on the final answer, and the permission tier
   gate on every tool call. `irreversible` needs an approval (the
   `human-in-the-loop` type) or is denied (every other type).
8. Tests: the registry test from step 3, a unit test per tool
   handler, a test that the gate denies an `irreversible` tool
   without approval, a test that the loop stops at
   `max_turns` and at `max_cost_usd`, a test that the kill switch
   stops a run. Eval set in `evals/<name>/trajectories.jsonl` (at least
   20 trajectories: input, expected tool sequence, expected outcome),
   for `llm-eval` to run later. Count trajectories. Run the suite
   with the granted command (`uv run pytest -s` or `npm test`, or the
   `make` target) and copy the `agent-tools:` line from its output.
9. Record the ADR, status Accepted only for what the user chose and
   Proposed otherwise, naming no decider who did not decide (`adr`, or a `docs/adr/` file in the same shape)
   with the type chosen, the cheaper type rejected, the model and the
   memory store, and the agent section of the HLD when one exists
   (`high-level-design`). Print the output contract.

## Output contract

```
## Agent: <name> (<type>, <python | typescript>)
model: <id>   effort: <level>   max_turns: N   max_cost_usd: N   timeout: N s
tools: <agent-tools counts line from the registry test, verbatim>
memory: window N turns, <summarise | none>, long-term: <store | none>
logging: <gateway module>   guardrails: <module>   kill switch: <flag name>
tests: N passed   eval trajectories: N in evals/<name>/trajectories.jsonl
ADR: docs/adr/NNNN-<kebab>.md   HLD: docs/design/<kebab>-hld.md
```

## Gotchas

- A tool without a tier is `irreversible` until someone says otherwise.
  Default to the strictest tier, not the loosest.
- `max_turns` alone does not bound cost; one turn can carry a huge tool
  result. Bound money from `usage`, not from counting turns.
- Return every tool result for a turn in one user message, including
  failures as `is_error: true`. Splitting them teaches the model to stop
  calling tools in parallel.
- Fable 5.1 rejects forced `tool_choice`. Use `auto` and an instruction;
  `strict: true` on the tool keeps the arguments schema-valid.
- The Claude Agent SDK is a different product from the SDK tool runner.
  Use it when the agent needs the built-in file, shell and search
  tools; not for an agent with three domain tools.
- LangGraph is an option for a `workflow` graph with many branches,
  not the default: it is a second runtime to trace, test and upgrade,
  and the tool runner plus a plain state machine covers most flows.
- The eval set is trajectories, not answers. A right answer reached by
  calling a `write` tool it did not need is a failure.
