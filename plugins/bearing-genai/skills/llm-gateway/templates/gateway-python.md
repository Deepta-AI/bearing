# Gateway, Python (FastAPI, uv)

Files under `llm/`: `gateway.py` (the interface and the pipeline),
`providers/anthropic.py`, `providers/fake.py`, `routing.py` (loads and
validates `routing.yaml`), `accounting.py`, `cache.py`, `limits.py`,
`redact.py`. Dependency: `anthropic` (1.x, built on `httpx2`). Nothing
outside `llm/` imports `anthropic`.

## Types

```python
from dataclasses import dataclass, field, replace
from typing import Any, Callable, Literal, Protocol
from uuid import UUID

@dataclass(frozen=True)
class LLMRequest:
    feature: str
    tenant_id: UUID
    messages: list[dict[str, Any]]
    system: str | None = None
    tools: list[dict[str, Any]] | None = None
    output_schema: dict[str, Any] | None = None
    tier: Literal["fast", "balanced", "deep"] | None = None   # route decides when None
    max_tokens: int | None = None
    idempotency_key: str | None = None
    model_override: str | None = None   # a key of routing.yaml `models:`; eval harnesses only
    check: Callable[[str], bool] | None = None   # format check for escalate_on: invalid

@dataclass(frozen=True)
class Usage:
    input_tokens: int
    output_tokens: int
    cache_read_input_tokens: int = 0
    cache_creation_input_tokens: int = 0

@dataclass(frozen=True)
class LLMResponse:
    text: str
    content: list[Any]              # raw blocks, for tool_use and citations
    model: str                      # from the response, not the request
    stop_reason: str
    usage: Usage
    cost_usd: float
    latency_ms: int
    request_id: str | None
    from_cache: bool = False
    fallback_reason: str | None = None
    escalated: bool = False         # a cascade route called its `then` model

class Provider(Protocol):
    def complete(self, model: str, req: LLMRequest, route: "Route") -> "ProviderResult": ...
    def stream(self, model: str, req: LLMRequest, route: "Route") -> "ProviderResult": ...
```

Errors: `LLMError` base; `FeatureDisabled`, `UnknownFeature`,
`RateLimited`, `ProviderUnavailable`, `Refused` (carries the
`stop_details` category), `ModelOverrideRefused`. The edge maps them to
503, 500, 429, 503, 422, 500.

`model_override` lets an eval harness (`llm-eval` step 4) run one feature
on another model. It names a key of the `models:` table in
`routing.yaml`, never a raw model id, so the provider and the price row
come with it. It is honoured only when the process has
`LLM_ALLOW_MODEL_OVERRIDE=1`; without it, or with a key the table does
not have, the gateway raises `ModelOverrideRefused` before any network
call. An overridden route is static with no fallback: a
`ProviderUnavailable` during an eval run raises instead of letting another
model answer, which would mix two models in one results file. Production
never sets the variable.

## Pipeline in `Gateway.complete`

```
route -> model override check -> kill switch -> idempotency lookup -> rate limit -> response cache
-> provider (retries) -> fallback -> cascade escalation -> accounting -> span -> refusal -> cache write
```

```python
class Gateway:
    def complete(self, req: LLMRequest) -> LLMResponse:
        route = self.routing.route(req.feature)               # UnknownFeature
        if req.model_override is not None:                    # before any network call
            if os.environ.get("LLM_ALLOW_MODEL_OVERRIDE") != "1" or req.model_override not in self.routing.models:
                raise ModelOverrideRefused(req.model_override)
            route = self.routing.with_model(route, req.model_override)   # a leg: the models: row's model, effort, max_tokens, timeout_s
            route = replace(route, fallback=None, strategy="static")      # one model per eval run
        if not route.enabled or os.environ.get(f"LLM_KILL_{req.feature.upper()}") == "1":
            raise FeatureDisabled(req.feature)
        if req.idempotency_key and (hit := self.idem.get(req.tenant_id, req.idempotency_key)):
            return hit
        self.limits.take(req.tenant_id, route.tier)           # RateLimited
        legs = self.routing.cascade_legs(route) if route.strategy == "cascade" else None
        first = legs.first if legs else self.routing.static_leg(route)   # a leg: its own model, effort, max_tokens, timeout_s
        key = self.cache.key(first.key, req) if route.cacheable else None
        if key and (hit := self.cache.get(key)):
            return replace(hit, from_cache=True)
        with self.tracer.start_as_current_span(f"chat {first.model}") as span:
            t0 = time.monotonic()
            used = first                                      # the Route whose prices bill this answer
            try:
                result = self._call(first.model, req, first)
            except ProviderUnavailable as e:
                if not route.fallback:
                    raise
                self.metrics.fallback.add(1, {"feature": req.feature, "reason": e.reason})
                fb = self.routing.resolve_fallback(route)
                used = fb
                result = self._call(fb.model, req, fb)
                result.fallback_reason = e.reason
            if legs and (why := self._escalate(route, req, result)):
                self.accounting.record(req, used, result, int((time.monotonic() - t0) * 1000))
                self.metrics.escalation.add(1, {"feature": req.feature})   # `why` goes on the span
                t0 = time.monotonic()
                used = legs.then                              # `cascade.then`, billed at its own prices
                result = self._call(used.model, req, used)    # once; never escalates again
                result.escalated = True
            resp = self.accounting.record(req, used, result, int((time.monotonic() - t0) * 1000))
            span.set_attributes(self._span_attrs(req, used, resp))
        if resp.stop_reason == "refusal":
            raise Refused(resp)
        if key:
            self.cache.put(key, resp)
        if req.idempotency_key:
            self.idem.put(req.tenant_id, req.idempotency_key, resp, ttl_s=86400)
        return resp
```

`_call` retries once on 529 with jitter after the SDK's own retries;
never on 400.

Every call goes out on a leg: a model (a `models:` key, with its
provider, prices and `id`), `effort`, `max_tokens` and `timeout_s`.
`routing.static_leg(route)` gives a static route's leg: its `leg:` when
model-routing wrote one, else the tier's settings with any `effort`,
`max_tokens` or `timeout_s` the route sets. `routing.with_model(route,
key)` gives an eval override's leg from the `models:` row: its `effort`,
`max_tokens` and `timeout_s`, the tier's where the row has none. Every
leg passes through `routing.leg()`, which sends the row's `id` as the
model (the key when the row has none) and drops `effort` when the row
sets `effort: null`, the mark of a model that rejects it (Haiku 4.5): an
override to `claude-haiku-4-5` on a `balanced` route sends no `effort`,
and neither does a static Haiku 4.5 route whose tier has one. The
routing schema accepts `leg:` on a route and `id`, `effort`,
`max_tokens` and `timeout_s` on a `models:` row.

A route with `strategy: cascade` calls `cascade.first`.
`routing.cascade_legs(route)` returns the two legs as routes: each takes
its model (provider and prices) from the `models:` key it names and its
own `effort`, `max_tokens` and `timeout_s` from the leg, never from the
route's tier, so a Haiku 4.5 leg with `effort: null` sends no `effort`.
The fallback, when the first model is unavailable, runs first and its
answer is what the cascade judges. `_escalate` returns the first `escalate_on` reason
that holds, else None: `refusal` (`stop_reason == "refusal"`), `max_tokens`
(`stop_reason == "max_tokens"`), `invalid` (the text does not parse against
`output_schema`, or `req.check` returns False). Those are the checks the
gateway can run, the same `valid` that `llm-eval` records and
`model-routing` simulates. On a reason the gateway records the first call
under the route that answered it (`first`, or `fb` after a fallback),
counts `llm_escalation_total{feature}` once, calls `cascade.then` once
and records that call under `then`, at its own prices and latency; that
answer stands whatever it is.

## Anthropic provider

```python
import anthropic

class AnthropicProvider:
    def __init__(self, timeout_s: float, max_retries: int = 2):
        self.client = anthropic.Anthropic(timeout=timeout_s, max_retries=max_retries)

    def complete(self, model: str, req: LLMRequest, route: Route) -> ProviderResult:
        client = self.client.with_options(timeout=route.timeout_s) if route.timeout_s else self.client
        kwargs: dict[str, Any] = dict(model=model, max_tokens=req.max_tokens or route.max_tokens,
                                      messages=req.messages)
        if req.system:
            block: dict[str, Any] = {"type": "text", "text": req.system}
            if route.prompt_cache:
                block["cache_control"] = {"type": "ephemeral"}
            kwargs["system"] = [block]
        if req.tools:
            kwargs["tools"] = req.tools
        if req.output_schema:
            kwargs["output_config"] = {"format": {"type": "json_schema", "schema": req.output_schema}}
        if route.effort:                                     # null (Haiku 4.5): no effort sent
            kwargs.setdefault("output_config", {})["effort"] = route.effort
        try:
            if route.stream or (req.max_tokens or route.max_tokens) > 16000:
                with client.messages.stream(**kwargs) as s:
                    msg = s.get_final_message()
            else:
                msg = client.messages.create(**kwargs)
        except anthropic.BadRequestError:
            raise                                             # never retried
        except anthropic.RateLimitError as e:
            raise ProviderUnavailable("rate_limited", retry_after=e.response.headers.get("retry-after"))
        except anthropic.APIStatusError as e:
            if e.status_code in (529, 500, 502, 503):
                raise ProviderUnavailable(f"http_{e.status_code}")
            raise
        except anthropic.APIConnectionError:
            raise ProviderUnavailable("connection")
        return ProviderResult(message=msg, request_id=msg._request_id)
```

Notes that hold on current models: thinking is adaptive by default on
Opus 5.5, Sonnet 5.5 and Fable 5.1; do not send `thinking`, `temperature`
or `budget_tokens` (400). Fable 5.1, Mythos 5.1, Opus 5.5 and Sonnet 5.5 reject forced `tool_choice`
(`any`, `tool`) with a 400, on `count_tokens` and batches too: send
`auto` with an instruction naming the tool, `strict: true` on the tool
for schema-valid arguments, or structured outputs (`output_schema`)
when the forced call only existed to get JSON back. Sonnet 5.5 rejects `thinking: {type: "disabled"}`;
`{type: "between_tools"}` turns it off at effort `high` or below. Opus
5.5 cannot disable thinking at all. None of them takes an assistant
prefill. Haiku 4.5 takes no `effort`, so its route sets it to null; it
keeps `budget_tokens` for thinking. Opus 5.5 and Fable 5.1 can
return `stop_reason: "refusal"`; the gateway raises `Refused` after
accounting so the call is still counted. Server-side fallbacks
(`betas=["server-side-fallback-2026-07-01"], fallbacks="default"` on
`client.beta.messages.create`) are an option per route; the gateway's
own fallback covers 429 and 529, which the server one does not.

## Accounting

```python
def cost_usd(prices: ModelPrice, u: Usage) -> float:
    return ((u.input_tokens * prices.input_per_m
             + u.cache_creation_input_tokens * prices.input_per_m * prices.cache_write_multiplier
             + u.cache_read_input_tokens * prices.input_per_m * prices.cache_read_multiplier
             + u.output_tokens * prices.output_per_m) / 1_000_000)
```

One record per call to ClickHouse `llm_calls` (`MergeTree` ordered by
`(tenant_id, feature, called_at)`, `DateTime64(3, 'UTC')`, batched
inserts through the existing events pipeline) or, without ClickHouse,
one structured log line `llm_call` with the same fields. Metrics from
the same record: `llm_calls_total{feature,model,status}`,
`llm_cost_usd_total{feature,tenant}`, `llm_fallback_total{feature,reason}`,
`llm_request_duration_seconds{feature,model}`,
`llm_escalation_total{feature}`; a route's alert on
`budget_usd_month` fires at 80 percent of `llm_cost_usd_total` for the
feature. A call made with
`model_override` is recorded with `override: true` and the overriding
key, so eval traffic never mixes with production cost.

## Logging

`redact.py` masks emails, phone numbers, `sk-ant-` keys and 12-digit
numbers. The log line carries `feature`, `tenant_id`, `model`,
`stop_reason`, tokens, `cost_usd`, `latency_ms`, `request_id`,
`trace_id`. Bodies (`system`, `messages`, `text`) are added only when
`LOG_LLM_BODIES=1`, after redaction, truncated to 2,000 characters.

## Fake provider and tests

```python
class FakeProvider:
    """Replays tests/llm/recordings/<feature>/<sha256 of the request>.json.
    RECORD_LLM=1 records from the real provider; CI never sets it."""
```

Tests in `tests/llm/`: `test_route_picks_tier`, `test_retry_529_then_ok`,
`test_no_retry_on_400`, `test_idempotent_replay_not_billed_twice`,
`test_rate_limit_per_tenant`, `test_kill_switch_before_network`,
`test_fallback_counted`, `test_cost_from_usage`,
`test_no_bodies_in_logs_by_default`, `test_refusal_raises_after_accounting`,
`test_model_override_refused_without_flag`,
`test_model_override_unknown_key_refused`,
`test_model_override_uses_model_effort` (an override to
`claude-haiku-4-5` on a `balanced` route sends no `output_config.effort`
and the row's `max_tokens`), `test_static_leg_settings` (a static
`leg:` with `effort: null` sends none whatever the tier says),
`test_model_override_skips_fallback` (the provider raises
`ProviderUnavailable`; the call raises and no fallback model is called),
`test_cascade_escalates_once` (an invalid `first` answer calls `then`
once, an invalid `then` answer is returned, not escalated again),
`test_escalation_counted` (one `llm_escalation_total`, two accounting
records, one per call, the second at the `then` model's prices),
`test_cascade_leg_settings` (a `first` leg with `effort: null` sends no
`output_config.effort`; each leg's `max_tokens` and `timeout_s` reach
the provider) and `test_no_escalation_when_valid`.
A laptop-only test `test_prompt_cache_hit` makes two identical calls and
asserts `cache_read_input_tokens > 0` on the second.

Makefile: `llm-audit` greps for call sites outside `llm/` and fails on
any; `llm-record` runs the recording tests with `RECORD_LLM=1`.
