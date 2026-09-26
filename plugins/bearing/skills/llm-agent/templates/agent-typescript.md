# Agent sketch, TypeScript (Node 24, `@anthropic-ai/sdk`, tool runner)

A sketch of the pieces, not a drop-in. Verify the runner hooks against
the SDK's own `helpers.md` (the `claude-api` skill lists the
repository). ESM, Zod, pino for the log lines, the prompt from the
registry (`prompt-registry`).

```typescript
import Anthropic from "@anthropic-ai/sdk";
import { betaZodTool } from "@anthropic-ai/sdk/helpers/beta/zod";
import { z } from "zod";
import pino from "pino";
import { load, render } from "../prompts/index.js";
import { REGISTRY, type ToolMeta } from "./registry.js";           // tool-registry.md
import { checkInput, checkOutput, gateTool } from "../guardrails/index.js"; // llm-guardrails
import { costUsd, killSwitchTripped } from "../llm/gateway.js";     // llm-gateway

const log = pino();

export interface Bounds { maxTurns: number; maxCostUsd: number; callTimeoutMs: number; wallClockMs: number }
const DEFAULT_BOUNDS: Bounds = { maxTurns: 10, maxCostUsd: 0.5, callTimeoutMs: 60_000, wallClockMs: 300_000 };

function gated<I>(meta: ToolMeta, requestId: string, run: (input: I) => Promise<string>) {
  return async (input: I): Promise<string> => {
    const started = Date.now();
    const verdict = gateTool(meta, input);
    if (!verdict.allowed) {
      log.info({ requestId, tool: meta.name, tier: meta.tier, reason: verdict.reason }, "tool.denied");
      return JSON.stringify({ error: verdict.reason, tool: meta.name });
    }
    let out: string, outcome = "ok";
    try {
      out = await Promise.race([run(input), timeout(meta.timeoutMs)]);
    } catch (e) {
      out = JSON.stringify({ error: (e as Error).name }); outcome = "error";
    }
    log.info({ requestId, tool: meta.name, tier: meta.tier, outcome, ms: Date.now() - started }, "tool.call");
    return out;
  };
}

const listOrders = (requestId: string) => betaZodTool({
  name: "list_orders",
  description: "Returns up to 20 orders for a customer id, newest first, totals in INR paise. Use find_customer to get the id first.",
  inputSchema: z.object({
    customer_id: z.string().describe("The customer's id, never an email"),
    limit: z.number().int().min(1).max(20).default(20),
  }),
  run: gated(REGISTRY.list_orders, requestId, async (input) => { /* ... */ return "[]"; }),
});

// Every tool sent to the model; the registry test calls this.
export const toolsFor = (requestId: string) => [listOrders(requestId)];

export async function run(task: string, requestId: string, bounds = DEFAULT_BOUNDS): Promise<string> {
  if (process.env.AGENT_KILL_SWITCH === "1" || (await killSwitchTripped("orders-agent"))) {
    log.warn({ requestId, reason: "switch" }, "agent.killed"); return "unavailable";
  }
  checkInput(task);                                                  // throws GuardrailError

  const p = load("orders_agent", 2);
  const tools = toolsFor(requestId);
  if (new Set(tools.map((t) => t.name)).size !== Object.keys(REGISTRY).length) throw new Error("registry and tools differ");

  const client = new Anthropic({ timeout: bounds.callTimeoutMs });     // milliseconds in this SDK
  const runner = client.beta.messages.toolRunner({
    model: p.model,                                                    // claude-opus-5 by default
    max_tokens: p.max_tokens,
    output_config: { effort: p.effort },
    system: [{ type: "text", text: render(p, {}), cache_control: { type: "ephemeral" } }],
    tools,
    messages: [{ role: "user", content: task }],
    max_iterations: bounds.maxTurns,
  });

  let spent = 0, turn = 0; const started = Date.now();
  for await (const message of runner) {
    turn += 1; spent += costUsd(p.model, message.usage);
    log.info({ requestId, agent: "orders-agent", turn, model: p.model, tokensIn: message.usage.input_tokens,
      tokensOut: message.usage.output_tokens, cacheRead: message.usage.cache_read_input_tokens,
      costUsd: spent, stop: message.stop_reason }, "model.call");
    if (message.stop_reason === "refusal") { log.warn({ requestId, details: message.stop_details }, "agent.refusal"); break; }
    if (spent > bounds.maxCostUsd || Date.now() - started > bounds.wallClockMs) { log.warn({ requestId, spent }, "agent.bounded"); break; }
    if (await killSwitchTripped("orders-agent")) { log.warn({ requestId, reason: "switch" }, "agent.killed"); break; }
  }
  const final = await runner.done();
  const text = final.content.filter((b) => b.type === "text").map((b) => b.text).join("");
  return checkOutput(text);                                           // schema, PII leak, policy
}

const timeout = (ms: number) => new Promise<never>((_, rej) => setTimeout(() => rej(new Error("ToolTimeout")), ms));
```

Notes:

- The runner returns each assistant message before the tools run, so
  an approval gate can also inspect pending `tool_use` blocks there and
  call `runner.setMessagesParams()` to deny before execution.
- The TS runner does not auto-resume `pause_turn`; check
  `stop_reason` and `runner.pushMessages` the paused turn, or keep
  server tools out of this agent.
- Streaming: construct the runner with `stream: true` and set
  `eager_input_streaming: true` on each client tool (spread it onto
  the `betaZodTool` result); validate the parsed input before running.
- Fable 5.1: omit `thinking`, keep `tool_choice` at `auto`, add the
  `fallbacks` parameter as the `claude-api` skill shows.
- Use SDK types (`Anthropic.MessageParam`, `Anthropic.ToolUseBlock`);
  do not redeclare them.
- Registry test: `src/agents/registry.test.ts` from `tool-registry.md`
  prints the `agent-tools:` counts line and fails on zero tools or a
  mismatch.
- Tests (vitest): handler unit tests; `gateTool` denies `irreversible`
  without approval; the loop stops at `maxCostUsd` with a fake client;
  the kill switch stops before the first call.
- Eval: `evals/orders-agent/trajectories.jsonl`, run by `llm-eval`.
