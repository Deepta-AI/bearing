# Gateway, TypeScript (Node 24)

Files under `src/llm/`: `gateway.ts`, `providers/anthropic.ts`,
`providers/fake.ts`, `routing.ts` (Zod schema for `routing.yaml`),
`accounting.ts`, `cache.ts`, `limits.ts`, `redact.ts`. Dependency:
`@anthropic-ai/sdk`. Nothing outside `src/llm/` imports it; an ESLint
`no-restricted-imports` rule enforces it.

## Types

```typescript
import Anthropic from "@anthropic-ai/sdk";
import { z } from "zod";

export const LLMRequest = z.object({
  feature: z.string(),
  tenantId: z.string().uuid(),
  messages: z.array(z.custom<Anthropic.MessageParam>()),
  system: z.string().optional(),
  tools: z.array(z.custom<Anthropic.Tool>()).optional(),
  outputSchema: z.record(z.unknown()).optional(),
  tier: z.enum(["fast", "balanced", "deep"]).optional(),
  maxTokens: z.number().int().positive().optional(),
  idempotencyKey: z.string().optional(),
  modelOverride: z.string().optional(),   // a key of routing.yaml `models:`; eval harnesses only
  check: z.function().args(z.string()).returns(z.boolean()).optional(), // format check for escalate_on: invalid
});
export type LLMRequest = z.infer<typeof LLMRequest>;

export interface LLMResponse {
  text: string;
  content: Anthropic.ContentBlock[];
  model: string;                 // from the response
  stopReason: string;
  usage: { inputTokens: number; outputTokens: number; cacheReadInputTokens: number; cacheCreationInputTokens: number };
  costUsd: number;
  latencyMs: number;
  requestId: string | null;
  fromCache?: boolean;
  fallbackReason?: string;
  escalated?: boolean;           // a cascade route called its `then` model
}

export interface Provider {
  complete(model: string, req: LLMRequest, route: Route): Promise<ProviderResult>;
}
```

Errors extend `LLMError`: `FeatureDisabled`, `UnknownFeature`,
`RateLimited`, `ProviderUnavailable` (with `reason`), `Refused`,
`ModelOverrideRefused`. The HTTP layer maps them to 503, 500, 429, 503,
422, 500. `modelOverride` follows the Python template: a key of the
`models:` table, honoured only with `LLM_ALLOW_MODEL_OVERRIDE=1`, else
`ModelOverrideRefused` before any network call; an overridden route is
static with no fallback, so an unavailable provider fails the eval call
instead of letting another model answer; accounting records
`override: true`.

## Pipeline

Same order as the Python template: route, model override check, kill
switch, idempotency lookup, rate limit, response cache, provider with
retries, fallback, cascade escalation, accounting, span, refusal raised
after accounting, cache write.

```typescript
async complete(input: LLMRequest): Promise<LLMResponse> {
  const req = LLMRequest.parse(input);
  let route = this.routing.route(req.feature);
  if (req.modelOverride !== undefined) {                  // before any network call
    if (process.env.LLM_ALLOW_MODEL_OVERRIDE !== "1" || !(req.modelOverride in this.routing.models)) {
      throw new ModelOverrideRefused(req.modelOverride);
    }
    route = this.routing.withModel(route, req.modelOverride); // a leg from the models: row
    route = { ...route, fallback: null, strategy: "static" };  // one model per eval run
  }
  if (!route.enabled || process.env[`LLM_KILL_${req.feature.toUpperCase()}`] === "1") {
    throw new FeatureDisabled(req.feature);
  }
  const idem = req.idempotencyKey && (await this.idem.get(req.tenantId, req.idempotencyKey));
  if (idem) return idem;
  await this.limits.take(req.tenantId, route.tier);
  const legs = route.strategy === "cascade" ? this.routing.cascadeLegs(route) : null;
  const first = legs ? legs.first : this.routing.staticLeg(route); // a leg: its own model, effort, maxTokens, timeoutS
  const key = route.cacheable ? this.cache.key(first.key, req) : null;
  const cached = key && (await this.cache.get(key));
  if (cached) return { ...cached, fromCache: true };
  return this.tracer.startActiveSpan(`chat ${first.model}`, async (span) => {
    let t0 = performance.now();
    let used: Route = first;                                // the Route whose prices bill this answer
    let result: ProviderResult;
    let fallbackReason: string | undefined;
    try {
      result = await this.call(first.model, req, first);
    } catch (e) {
      if (!(e instanceof ProviderUnavailable) || !route.fallback) throw e;
      this.metrics.fallback.add(1, { feature: req.feature, reason: e.reason });
      const fb = this.routing.resolveFallback(route);
      used = fb;
      result = await this.call(fb.model, req, fb);
      fallbackReason = e.reason;
    }
    let escalated = false;
    const why = legs ? this.escalateReason(route, req, result) : null;
    if (legs && why) {                                      // escalate_on: invalid, refusal, max_tokens
      await this.accounting.record(req, used, result, Math.round(performance.now() - t0), fallbackReason);
      this.metrics.escalation.add(1, { feature: req.feature });
      t0 = performance.now();
      used = legs.then;                                     // `cascade.then`, billed at its own prices
      result = await this.call(used.model, req, used);      // once; never escalates again
      escalated = true;
      fallbackReason = undefined;                           // the reason belonged to the first call
    }
    const resp = { ...(await this.accounting.record(req, used, result, Math.round(performance.now() - t0), fallbackReason)), escalated };
    span.setAttributes(this.spanAttrs(req, used, resp));
    span.end();
    if (resp.stopReason === "refusal") throw new Refused(resp);
    if (key) await this.cache.put(key, resp);
    if (req.idempotencyKey) await this.idem.put(req.tenantId, req.idempotencyKey, resp, 86_400);
    return resp;
  });
}
```

## Anthropic provider

```typescript
export class AnthropicProvider implements Provider {
  private client: Anthropic;
  constructor(timeoutMs: number, maxRetries = 2) {
    this.client = new Anthropic({ timeout: timeoutMs, maxRetries }); // milliseconds, not seconds
  }

  async complete(model: string, req: LLMRequest, route: Route): Promise<ProviderResult> {
    const maxTokens = req.maxTokens ?? route.maxTokens;
    const params: Anthropic.MessageCreateParams = { model, max_tokens: maxTokens, messages: req.messages };
    if (req.system) {
      params.system = [{ type: "text", text: req.system,
        ...(route.promptCache ? { cache_control: { type: "ephemeral" } } : {}) }];
    }
    if (req.tools) params.tools = req.tools;
    if (req.outputSchema) params.output_config = { format: { type: "json_schema", schema: req.outputSchema } };
    if (route.effort) params.output_config = { ...(params.output_config ?? {}), effort: route.effort };
    const opts = route.timeoutS ? { timeout: route.timeoutS * 1000 } : {}; // a leg's own timeout, milliseconds
    try {
      const msg = route.stream || maxTokens > 16_000
        ? await this.client.messages.stream(params, opts).finalMessage()
        : await this.client.messages.create(params, opts);
      return { message: msg, requestId: msg._request_id ?? null };
    } catch (e) {
      if (e instanceof Anthropic.BadRequestError) throw e;                       // never retried
      if (e instanceof Anthropic.RateLimitError) throw new ProviderUnavailable("rate_limited");
      if (e instanceof Anthropic.APIError && [500, 502, 503, 529].includes(e.status ?? 0)) {
        throw new ProviderUnavailable(`http_${e.status}`);
      }
      if (e instanceof Anthropic.APIConnectionError) throw new ProviderUnavailable("connection");
      throw e;
    }
  }
}
```

Legs follow the Python template: `routing.staticLeg(route)` (a route's
`leg:`, else its tier) and `routing.withModel(route, key)` (the
`models:` row's `effort`, `maxTokens` and `timeoutS`) both go through
`routing.leg()`, which sends the row's `id` and drops `effort` for a row
with `effort: null`: an override to `claude-haiku-4-5` on a `balanced` route sends no `effort`.
The Zod schema accepts `leg` on a route and `id`, `effort`,
`max_tokens` and `timeout_s` on a `models:` row.

Same model notes as the Python template: no `thinking` or
`temperature` or `budget_tokens` on Opus 5.5, Sonnet 5.5 and Fable 5.1;
`effort` inside `output_config`; Sonnet 5.5 turns thinking off with
`between_tools`, never `disabled`; no assistant prefill; Haiku 4.5 without
`effort` (it keeps `budget_tokens`); Fable 5.1, Mythos 5.1, Opus 5.5 and Sonnet 5.5 reject forced `tool_choice`
(`any`, `tool`), so send `auto` with an instruction, `strict: true`, or
structured outputs; `stop_reason` read before
`content`; `_request_id` logged on failures.

## Accounting, logging, tests

Cost formula, ClickHouse `llm_calls` record, metric names, redaction
rules and the `LOG_LLM_BODIES` toggle are the same as the Python
template. `FakeProvider` replays `tests/llm/recordings/<feature>/<sha256>.json`;
`RECORD_LLM=1` records on a laptop only. The cascade follows the Python
template: `routing.cascadeLegs(route)` gives each leg its own model,
`effort` (a Haiku 4.5 leg sets null and sends none), `maxTokens` and
`timeoutS`; the fallback runs first, `escalateReason` checks
`escalate_on` once, the first call is recorded under the route that
answered (`first`, or `fb` after a fallback) and the escalated one under
`then`, and `llm_escalation_total{feature}` counts the escalation. The
vitest suite covers the same nineteen cases,
`model_override refused without flag`, `model_override unknown key
refused`, `model_override uses model effort`, `static leg settings`,
`model_override skips fallback`, `cascade escalates once`,
`escalation counted`, `cascade leg settings` and `no escalation when
valid` among them. `npm run llm:audit`
greps for `@anthropic-ai/sdk` and `messages.create(` outside `src/llm/`
and fails on any hit; the count
found is printed.
