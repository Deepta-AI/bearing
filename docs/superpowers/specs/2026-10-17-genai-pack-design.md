# GenAI pack: the `bearing-genai` plugin

Status: draft for review, 2026-10-17. Branch `feat/GenAIPack`.
Sub-project 4 of 4 in the Bearing improvement programme. Sub-project 2
(design pipeline) is in flight on `feat/DesignPipeline` and changes the
greenfield flow and the autopilot stages; section F says how this one
composes with it.

## Intent

The user's words, binding: "GenAI workflows and implementation for RAG
(all types), Model routing (right model routing for cost optimisation),
MCP, Agents building with different framework, voice agents, bots,
chatbots, Model training, Dataset generation, better evals."

The user skipped the brainstorming questions. Every choice below that is
not quoted from the user is marked **author's call**.

Why: Bearing has GenAI skills, but they are a shelf of parts, not a
workflow. There is no flow that walks a GenAI feature from problem to
release, no first-class way to pick the cheapest model that still passes,
no way to make data when real data is short, and the eval skill stops at
a mean score and a fixed delta. Conversational products (chatbots, bots,
multi-turn voice agents), agent frameworks other than the Anthropic SDK,
full model training and per-type RAG implementation are missing or thin.
And the `bearing` plugin is full: 508 of 512 files.

## What exists (v0.8.0)

- 12 GenAI and ML skills in `plugins/bearing/skills/`: `genai-design`,
  `rag` (types naive, hybrid, reranked, hierarchical, graph, agentic, sql,
  multimodal, long-context; one retriever template for all),
  `llm-agent` (Anthropic SDK only; LangGraph named as an option),
  `llm-eval` (golden set, graders, judge, fixed-delta gate),
  `llm-fine-tuning` (LoRA, DPO, distillation, continued pretraining on
  open models), `llm-gateway` (tiers, retries, caching, cost, fallbacks,
  price table in `routing.yaml`), `llm-guardrails`, `prompt-registry`,
  `speech` (WER, latency, barge-in; `realtime` is one job among four),
  `mcp-server`, `computer-vision`, `tabular-ml`. 57 files in all.
- The `llm` autopilot profile: `genai-design` in the design stage,
  `llm-guardrails` and `llm-eval` in `test_automation`
  (`plugins/bearing/bin/brg-autopilot`, gates at the design and
  test_automation checks).
- Flows: greenfield and feature each have a "Calls to a model" branch
  with `genai-design`, `llm-guardrails`, `llm-eval`. No GenAI flow.
- Model ids in the skills are a generation old: `claude-opus-5`,
  `claude-sonnet-5`, `claude-haiku-4-5` (unpinned alias),
  `claude-fable-5-1` as the strongest option.
- Stack plugins `bearing-backend` (252 files) and `bearing-apps` (382)
  set the pattern: `.claude-plugin/plugin.json`, `README.md`, `LICENSE`,
  `skills/`; one marketplace entry each; `lint-version` keeps all
  versions equal to `VERSION`; `brg-kit-paths` finds siblings by name
  (`SIBLINGS`, `owner_of`); `install.sh` installs `PLUGINS`; `brg-doctor`
  reports each optional plugin; references to bearing skills are written
  `bearing:<name>`, and `tests/integration/plugin_split.sh` fails a
  sibling document that reaches into its own `${CLAUDE_PLUGIN_ROOT}` for
  bearing paths.

## Goals

1. A third optional plugin, `bearing-genai`, holds every GenAI and ML
   skill, and `bearing` drops to about 451 files.
2. A GenAI flow in `docs/flows.json` that the handbook draws and
   `brg-session next-step` follows.
3. Cost-based model routing as its own skill, deciding from measured
   scores and costs, provider-neutral.
4. Evals that say whether a difference is real: confidence intervals,
   paired comparison, judge calibration against people.
5. Dataset generation that is seeded from real data, deduplicated,
   checked for contamination against the eval set, audited by a person
   and documented.
6. Phases 2 and 3 (below) cover chatbots and bots, multi-turn voice
   agents, agent frameworks, RAG implementation per type, full model
   training and deeper MCP, each planned on its own.

## Non-goals

- No change to how `bearing`'s non-GenAI skills behave.
- No hosted service, no telemetry, no API key in the kit. Skills write
  code that reads keys from the product's environment.
- No benchmark leaderboard. Routing decides on the product's own golden
  set, never on public benchmark scores.
- No new autopilot stage in phase 1 (**author's call**: the `llm` profile
  already places GenAI work in design and test_automation; a stage of
  its own waits until sub-project 2's stage order has landed).

## Anti-goals

- A synthetic dataset that measures the generator. Synthetic rows never
  replace real seed rows and never leak into the set that grades them.
- A cheaper route chosen on a mean that sits inside the noise.
- Framework sprawl: one agent contract that every framework template
  implements, not one design per framework.

## Constraints

- No em dashes in any file (`lint-prose`).
- Every gate fails on zero input and prints the count it checked.
- `SKILL.md` at most 200 lines (`lint-skill-size`); detail goes in
  `references/`.
- A skill that asks the user does it with AskUserQuestion and names
  `references/console.md` (`lint-questions`); for `bearing-genai` that is
  the bearing plugin's file, named as text, not through its own
  `${CLAUDE_PLUGIN_ROOT}`.
- Every command a skill runs is granted in its `allowed-tools`
  (`lint-tools`).
- Scripts are bash 3.2 portable and Python 3 stdlib only.
- Bearing never pushes, merges, tags or deploys; it prints the command.
- Every external fetch is pinned in `plugins/bearing/bin/pinned-packs.txt`
  (`tests/unit/pins_match.sh`); phase 1 adds none.
- Every skill has `evals/<name>/evals.json` and an entry in
  `evals/triggers.json` (3 should, 2 near misses); `evals/.pending` only
  shrinks.
- Defaults: `claude-opus-5-5` (deep, the default tier),
  `claude-sonnet-5-5` (balanced), `claude-haiku-4-5` (fast; `claude-haiku-5-5`
  does not exist, controller correction 2026-10-18); routing is provider-neutral (Anthropic, OpenAI,
  Google, OpenRouter, a served open model through vLLM or any
  OpenAI-compatible endpoint).
- The four plugins move in version lockstep (`lint-version`).

## Design

### A. The plugin

`plugins/bearing-genai/` in the layout of `bearing-backend`:
`.claude-plugin/plugin.json` (name `bearing-genai`, version = `VERSION`,
description "Bearing GenAI and ML skills: solution design, RAG, agents,
MCP, gateway and model routing, evals, datasets, guardrails, prompts,
fine-tuning, speech, vision and tabular ML. Needs the bearing plugin.",
keywords), `README.md`, `LICENSE` (copy of the bearing one),
`skills/`. A marketplace entry after `bearing-apps`, category
`development`, the marketplace description naming it.

**Move all 12 GenAI and ML skills** (**author's call**). The other option
was to keep `genai-design`, `llm-guardrails` and `llm-eval` in `bearing`
because autopilot's `llm` profile calls them. Rejected: the pack would be
split across two plugins, the eval deepening would add files to the full
plugin, and the dependency would point the wrong way for the skills that
build on each other. `computer-vision` and `tabular-ml` move too because
the handbook's GenAI stage already holds them ("anything that calls,
trains or serves a model"). Moved with `git mv`, history kept. Their
evals, triggers and fixture folders stay where they are (`evals/<name>/`
is keyed by name, not plugin).

Names after the move. A skill's bare name stays unique across plugins
(`lint-skills` already fails on a duplicate), so `/rag` still resolves
when both plugins are installed. Every prefixed reference changes:
inside `bearing`, the bare mentions of moved skills in
`workflow/SKILL.md`, `autopilot/references/*.md`,
`tech-decision/references/catalogue.md`,
`high-level-design/references/traps.md` and
`observability/references/telemetry-conventions.md` become
`bearing-genai:<name>`; inside `bearing-genai`, references to bearing
skills become `bearing:<name>` (`tech-decision`, `adr`,
`observability`, `db-migration`, `ci-pipeline`, `high-level-design`,
`webhooks`). `lint-skills` learns the `bearing-genai:` prefix so each of
these is checked to exist. There are no `bearing:<moved>` references in
the repository today, so nothing else breaks.

Cross-plugin files. The decision protocol line becomes the
`bearing-backend:infra` form ("follows the decision protocol of the
`bearing:tech-decision` skill (references/decision-protocol.md in the
bearing plugin)"); the two `${CLAUDE_PLUGIN_ROOT}/references/console.md`
mentions (`llm-guardrails`, `mcp-server`) become "the bearing plugin's
`references/console.md`". A genai skill's own scripts keep
`${CLAUDE_PLUGIN_ROOT}/skills/<skill>/scripts/...`, which is right in its
own plugin. `plugin_split.sh` checks `bearing-genai` documents too and
allows a `${CLAUDE_PLUGIN_ROOT}/skills/<x>/` path only when that path
exists inside the same plugin.

Resolver and installer: `brg-kit-paths` gains `bearing-genai` in
`SIBLINGS` and an `owner_of` case for the 12 names plus the new ones;
`install.sh` adds it to `PLUGINS` (installed by default like the stack
plugins); `brg-doctor` reports it as optional; `bin/trigger-eval.py`,
`bin/skill-evals.py`, `bin/kit_paths.py` and `bin/lint-version.py` name
four plugins; the path rows of moved files in
`bin/lint-skill-size.allow` (`llm-guardrails` at 217 lines),
`bin/lint-templates.skip`, `tests/unit/pins_match.py`,
`tests/unit/llm_callsites.sh` and `tests/unit/ai_depth_scripts.sh` follow
the move; README, `docs/INSTALL.md`, `CONTRIBUTING.md`, the plugin
READMEs and the `new-skill` skill name it as the home for GenAI skills.

Autopilot dependency. `brg-autopilot profile --llm yes` resolves
`genai-design` through `brg-kit-paths --skill`; when it is missing it
exits 2 with the install hint and records no profile, so an unattended
run never reaches the design stage without the skills it needs.
Everything else about the `llm` profile is unchanged.

### B. Model ids

`bin/model-ids.txt` (repository tool, not shipped in a plugin) lists
every Claude id our own text may name, one row
`default|<id>|<tier>` or `option|<id>|<why>`:

```
default|claude-opus-5-5|deep
default|claude-sonnet-5-5|balanced
default|claude-haiku-4-5|fast
option|claude-fable-5-1|the highest tier, for a route the eval shows needs it
option|claude-haiku-4-5-20251001|dated snapshot of claude-haiku-4-5, allowed alias
option|claude-opus-5|previous Opus, still active in the claude-api skill
option|claude-sonnet-5|previous Sonnet, still active in the claude-api skill
```

`bin/lint-model-ids.py` (target `lint-model-ids`, in `make check`) scans
every file under `plugins/` for `claude-(opus|sonnet|haiku|fable|mythos)-N(-N)*`
and fails on an id not in the file; prints files scanned and ids found;
fails when it scanned zero files. Eval fixture recordings under `evals/`
are a user's repository frozen in time and are not scanned. Every moved
skill, template and reference moves to the three defaults; the gateway's
`routing.yaml` template gets the current prices from the `claude-api`
skill with an `as_of` and `source` line. Skills keep the rule "load
`claude-api` for ids and prices; never from memory".

### C. Evals that separate signal from noise (`llm-eval`, deepened)

The golden set, graders and baseline stay. Added:

1. **Statistics** in `scripts/eval_stats.py` (stdlib): `summary`
   (mean, bootstrap 95% interval with a fixed seed, n, truncated),
   `compare` (paired bootstrap on per-case deltas over the case ids two
   runs share; prints the delta, its interval and `better | worse |
   no difference`), `agree` (judge against person labels: percent
   agreement and Cohen's kappa). Each fails on zero cases or zero shared
   ids. The CI gate moves from "drop more than 0.02" to "the paired
   interval's upper bound is below zero" (`gate.yaml method: paired`),
   with the fixed delta kept as `method: delta` for sets under 30 cases
   (**author's call**: a bootstrap on fewer than 30 is not worth trusting).
2. **Judge calibration**: a judge grader is trusted only after `agree`
   shows kappa >= 0.6 on at least 30 person-labelled items
   (**author's call** on both numbers); below that the judge's score is
   reported as `uncalibrated` and the gate does not use it.
3. **Run records for routing**: the harness takes `--model <id>`. The
   gateway honours `LLMRequest.model_override` only when
   `LLM_ALLOW_MODEL_OVERRIDE=1` is set (the eval environment; a production
   caller cannot change its own model, **author's call**); without a
   gateway the harness passes the id to the SDK call. It writes per case `case_id`, `score` (0 to 1), `model` from the
   response, `usage`, `cost_usd`, `latency_ms`, `truncated` and `valid`
   (every deterministic grader passed). `cost_usd` comes from the
   gateway's price table; a model without a price writes `null` and the
   frontier script refuses it.
4. `references/eval-methods.md`: judge biases (position, verbosity, self
   preference) and their controls, the noise floor, contamination,
   rubric writing, when pairwise beats pointwise.

### D. Model routing (`model-routing`, new)

"Right model routing for cost optimisation" as a skill that decides
from evidence. Argument `<feature|all> [--threshold <x>] [--candidates <id,...>]`.

1. Features and volume from `llm/routing.yaml` and the gateway's
   accounting (`llm_calls`), else the call-site gate's inventory.
2. Candidates per feature: the three defaults plus anything the user or
   `--candidates` names, any provider, each with a price row in the
   gateway's price table (asked for, with source and date, when missing).
3. Measure: `llm-eval`'s harness once per candidate with `--model`.
   No golden set: the `llm-eval` minimal path (10 labelled cases, marked
   `minimal`), and the decision is reported as provisional.
4. Decide with `scripts/route_frontier.py`: per candidate the mean, the
   interval's lower bound, cost per 1,000 requests and p95 latency; for
   each cheaper-to-dearer pair a simulated **cascade** (small model
   first; when its answer is not `valid`, pay for the large one too).
   It chooses the cheapest option whose lower bound is at or above the
   threshold, ties broken by p95. The threshold is `--threshold`, else
   the acceptance threshold in `docs/genai/<feature>-solution.md`, else
   asked. A cascade is simulated only over cases that both runs share
   and only when the small model's rows carry `valid`; a feature with no
   deterministic grader gets static candidates only, and the output says so. It exits 1 when nothing meets the
   threshold or when given no cases, and prints
   `route-frontier: C candidates, N cases, chose <x> ...`.
5. Write the route: `strategy: static | cascade`, `escalate_on`
   (`invalid`, `refusal`, `max_tokens`), the evidence as a comment
   (frontier line, date, eval version), `budget_usd_month` with an alert
   at 80 percent through `bearing:observability`. The gateway templates
   gain the cascade path (one escalation, counted in
   `llm_escalation_total{feature}`). A third strategy, a classifier that
   picks the tier per request, is described in the reference and left
   to the builder of a product that shows the need (**author's call**:
   it needs per-request difficulty labels the first release does not
   have).
6. `docs/genai/routing.md`: one row per feature with chosen route, score,
   cost per 1,000, monthly estimate at current volume, and the date to
   re-run (when a model id or a price changes, or 90 days).

### E. Dataset generation (`dataset-generation`, new)

Argument `<eval|train|preference> <name> [--seed <path>] [--target N]`.

1. Seed: at least 10 real examples; fewer stops the skill ("synthetic
   data with no real seed measures the generator").
2. Taxonomy: the dimensions that matter (intent, difficulty, language
   including code-mixed, length, edge case, adversarial) as
   `datasets/<name>/taxonomy.json`, cells from the solution doc and the
   eval's worst cases.
3. Generate through the gateway with a versioned prompt
   (`prompt-registry`). For eval rows the generator is a different model
   family or tier from the model under test (**author's call**); for
   training rows a teacher that the eval shows is better.
4. Filter: schema, exact and near-duplicate removal (character 5-gram
   Jaccard >= 0.8, **author's call**), then contamination against
   `evals/<name>/cases.jsonl`: zero overlap allowed for `train` and
   `preference`.
5. Audit: a person checks 10 percent or 30 rows, whichever is larger;
   acceptance below 90 percent sends the batch back (**author's call**).
6. Eval rows are marked `source: synthetic`, join the golden set only
   after the audit, and stay at most half of it (**author's call**).
7. `datasets/<name>/DATASHEET.md`: provenance, seed licence, generator
   ids and prompt versions, PII handling, audit result, intended use.

`scripts/dataset_check.py` (stdlib) is the gate: rows, rows per cell,
empty cells, exact and near duplicates, contamination, rows missing
`source`, audit coverage. Exit 1 on zero rows, on any contamination for
train or preference, on unaudited synthetic eval rows; it prints every
count. `llm-fine-tuning`'s data step calls this skill instead of its
own generation notes.

### F. The GenAI flow and how it composes

A fifth flow, id `genai`, "GenAI feature or product": "Anything whose
behaviour comes from a model: retrieval, agents, chatbots, voice,
training." Phases and steps (pack `bearing-genai` unless noted):

- **Frame**: `start-task` (bearing); `genai-design`; branch "Is a
  provider, model or store still open?" yes: `tech-decision` (bearing).
- **Set the bar**: branch "Is there enough real data for a golden set?"
  no: `dataset-generation`; then `llm-eval` (the set and the gate first,
  before the build).
- **Build**: branch "What is being built?" with options Retrieval
  (`rag`), An agent (`llm-agent`), Tools for models (`mcp-server`),
  Speech or voice (`speech`), Vision (`computer-vision`), Tabular ML
  (`tabular-ml`), Training (`llm-fine-tuning`); then `prompt-registry`.
- **Every call**: `llm-gateway`, then `model-routing`.
- **Prove it**: `llm-guardrails`; `llm-eval` again as the gate run;
  `definition-of-done`, `branch-review`, `merge-request` (bearing).

Phase 2 adds Chatbot or bot and Voice agent options; phase 3 adds the
framework branch under An agent.

Composition (**author's call**): greenfield and feature keep their "Calls
to a model" branch and its three steps (pack becomes `bearing-genai`), and
each gains a last step, a link to the `genai` flow. The edit touches only
that option, found by its label, so it survives sub-project 2's reordering
of greenfield. In autopilot, `genai-design` stays in the design stage;
sub-project 2's `contract` stage comes after it and reads
`docs/genai/*-solution.md` when the profile says `llm` (streaming
endpoints and async jobs belong in the contract). That reading is
sub-project 2's to add or a follow-up here, whichever lands second.
`brg-session next-step` follows the `genai` flow on a branch whose
timeline includes `genai-design`; otherwise bugfix or feature as today.
`gen-guide.py` adds the new skills to the `genai` category and two stage
rows (model routing, dataset generation) with `from` set to
`bearing-genai` on every GenAI row; the site's flow colour maps gain
`genai`.

### G. Later phases (planned separately)

**Phase 2, conversations.**
- `chatbot` (new; covers "bots" and "chatbots"): argument
  `<web|slack|teams|whatsapp|telegram|discord> <name>`. Conversation
  store and history window with summarisation, memory policy, human
  handoff, streaming, channel adapters with signature checks
  (`bearing:webhooks`), idempotent handling of channel retries, per-user
  rate limits, guardrails on both sides, analytics (containment,
  handoff rate, turns to resolution).
- `voice-agent` (new): cascade (VAD, streaming ASR, LLM, TTS) or a
  speech-to-speech model, chosen through `bearing:tech-decision`;
  endpointing and turn-taking, barge-in, dialogue state and tool calls,
  telephony through the Twilio pack; a per-turn latency budget measured
  with `speech`'s `latency_report.py`; multi-turn call evals replaying
  scripted caller turns through TTS. `speech` keeps batch, TTS and
  analytics and hands `realtime` to `voice-agent`.
- `llm-eval --task conversation`: a simulated user (persona, goal, turn
  limit) and grading on goal completion, turns to goal and policy
  breaches; shared by both skills.

**Phase 3, breadth.**
- Agent frameworks: `llm-agent --framework` with the Anthropic SDK as the
  default and templates for Claude Agent SDK, LangGraph, OpenAI Agents
  SDK, Pydantic AI, Google ADK, CrewAI and, for TypeScript, Mastra and
  the Vercel AI SDK; `references/frameworks.md` as the selection matrix;
  a `tech-decision` catalogue key "agent framework". Every template
  implements the same contract: registry with tiers, bounds, call log,
  kill switch, trajectory evals. Each framework package pinned.
- RAG per type: `references/types/<type>.md` for each of the nine types
  (when, schema delta, retriever shape, eval specifics, failure modes)
  and `llm-eval --task rag-answer` (faithfulness, citation precision).
- `model-training` (new): full training and fine-tuning of whole models,
  distributed training, experiment tracking, checkpoint and resume,
  deterministic data loading, a compute budget gate, evals during
  training. `llm-fine-tuning` keeps adapters and distillation.
- `mcp-server`: remote streamable HTTP with OAuth, the client side in
  agents, a server registry.
- Online evals: production samples into a person's review queue.

## Left to the builder

- Wording of descriptions, trigger phrases and eval prompts within the
  lint rules.
- Exact layout of `eval_stats.py`, `route_frontier.py` and
  `dataset_check.py` internals, given the interfaces in the plan.
- Bootstrap resample count (the plan uses 2,000) and seed.
- Order of moved files inside each commit.

## Decisions

Both decided by the user on 2026-10-18.

1. Fast default model: `claude-haiku-4-5` (controller correction,
   2026-10-18). The earlier ruling named `claude-haiku-5-5`; that model does
   not exist, and the `claude-api` skill lists only `claude-haiku-4-5`
   (dated snapshot `claude-haiku-4-5-20251001`, $1 / $5 per MTok, thinking
   by `budget_tokens`, no `effort`). The gateway template, `bin/model-ids.txt`
   and the routing tables use `claude-haiku-4-5`; the snapshot is an `option`
   row (allowed alias). `claude-haiku-5-5` is unknown to `lint-model-ids`.
2. Default install: "`bearing-genai` installs by default from `install.sh`,
   like the stack plugins." It is not on-request only.

## Acceptance for phase 1

- `make check` passes; `lint-plugin-size` prints bearing at or below
  455 files and bearing-genai under 512.
- `make lint-model-ids` prints a non-zero file count and 0 unknown ids.
- `bash plugins/bearing/bin/brg-kit-paths --skill rag` prints the
  `bearing-genai` path; with only `bearing` installed it exits 1 naming
  `bearing-genai@bearing`.
- `docs/flows.json` has five flows; `make docs` draws the `genai` flow.
- `route_frontier.py`, `eval_stats.py` and `dataset_check.py` each have
  unit tests that cover the empty-input failure.
- Version 0.9.0 in every manifest; CHANGELOG entry; the push command
  printed, not run.
