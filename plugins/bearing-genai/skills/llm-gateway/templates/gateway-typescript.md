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
}

export interface Provider {
  complete(model: string, req: LLMRequest, route: Route): Promise<ProviderResult>;
}
```

Errors extend `LLMError`: `FeatureDisabled`, `UnknownFeature`,
`RateLimited`, `ProviderUnavailable` (with `reason`), `Refused`. The
HTTP layer maps them to 503, 500, 429, 503, 422.

## Pipeline

Same order as the Python template: kill switch, route, idempotency
lookup, rate limit, response cache, provider with retries, fallback,
accounting, span, cache write, refusal raised after accounting.

```typescript
async complete(input: LLMRequest): Promise<LLMResponse> {
  const req = LLMRequest.parse(input);
  const route = this.routing.route(req.feature);
  if (!route.enabled || process.env[`LLM_KILL_${req.feature.toUpperCase()}`] === "1") {
    throw new FeatureDisabled(req.feature);
  }
  const idem = req.idempotencyKey && (await this.idem.get(req.tenantId, req.idempotencyKey));
  if (idem) return idem;
  await this.limits.take(req.tenantId, route.tier);
  const key = route.cacheable ? this.cache.key(route.model, req) : null;
  const cached = key && (await this.cache.get(key));
  if (cached) return { ...cached, fromCache: true };
  return this.tracer.startActiveSpan(`chat ${route.model}`, async (span) => {
    const t0 = performance.now();
    let result: ProviderResult;
    let fallbackReason: string | undefined;
    try {
      result = await this.call(route.model, req, route);
    } catch (e) {
      if (!(e instanceof ProviderUnavailable) || !route.fallback) throw e;
      this.metrics.fallback.add(1, { feature: req.feature, reason: e.reason });
      const fb = this.routing.resolveFallback(route);
      result = await this.call(fb.model, req, fb);
      fallbackReason = e.reason;
    }
    const resp = await this.accounting.record(req, route, result, Math.round(performance.now() - t0), fallbackReason);
    span.setAttributes(this.spanAttrs(req, route, resp));
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
    try {
      const msg = route.stream || maxTokens > 16_000
        ? await this.client.messages.stream(params).finalMessage()
        : await this.client.messages.create(params);
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

Same model notes as the Python template: no `thinking` or
`temperature` on Opus 5, Sonnet 5 and Fable 5.1; `effort` inside
`output_config`; Haiku 4.5 without `effort`; `stop_reason` read before
`content`; `_request_id` logged on failures.

## Accounting, logging, tests

Cost formula, ClickHouse `llm_calls` record, metric names, redaction
rules and the `LOG_LLM_BODIES` toggle are the same as the Python
template. `FakeProvider` replays `tests/llm/recordings/<feature>/<sha256>.json`;
`RECORD_LLM=1` records on a laptop only. The vitest suite covers the
same ten cases. `npm run llm:audit` greps for `@anthropic-ai/sdk` and
`messages.create(` outside `src/llm/` and fails on any hit; the count
found is printed.
