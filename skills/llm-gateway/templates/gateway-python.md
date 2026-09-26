# Gateway, Python (FastAPI, uv)

Files under `llm/`: `gateway.py` (the interface and the pipeline),
`providers/anthropic.py`, `providers/fake.py`, `routing.py` (loads and
validates `routing.yaml`), `accounting.py`, `cache.py`, `limits.py`,
`redact.py`. Dependency: `anthropic` (1.x, built on `httpx2`). Nothing
outside `llm/` imports `anthropic`.

## Types

```python
from dataclasses import dataclass, field
from typing import Any, Literal, Protocol
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

class Provider(Protocol):
    def complete(self, model: str, req: LLMRequest, route: "Route") -> "ProviderResult": ...
    def stream(self, model: str, req: LLMRequest, route: "Route") -> "ProviderResult": ...
```

Errors: `LLMError` base; `FeatureDisabled`, `UnknownFeature`,
`RateLimited`, `ProviderUnavailable`, `Refused` (carries the
`stop_details` category). The edge maps them to 503, 500, 429, 503, 422.

## Pipeline in `Gateway.complete`

```
kill switch -> route -> idempotency lookup -> rate limit -> response cache
-> provider (retries) -> refusal or fallback -> accounting -> span -> cache write
```

```python
class Gateway:
    def complete(self, req: LLMRequest) -> LLMResponse:
        route = self.routing.route(req.feature)               # UnknownFeature
        if not route.enabled or os.environ.get(f"LLM_KILL_{req.feature.upper()}") == "1":
            raise FeatureDisabled(req.feature)
        if req.idempotency_key and (hit := self.idem.get(req.tenant_id, req.idempotency_key)):
            return hit
        self.limits.take(req.tenant_id, route.tier)           # RateLimited
        key = self.cache.key(route.model, req) if route.cacheable else None
        if key and (hit := self.cache.get(key)):
            return replace(hit, from_cache=True)
        with self.tracer.start_as_current_span(f"chat {route.model}") as span:
            t0 = time.monotonic()
            try:
                result = self._call(route.model, req, route)
            except ProviderUnavailable as e:
                if not route.fallback:
                    raise
                self.metrics.fallback.add(1, {"feature": req.feature, "reason": e.reason})
                fb = self.routing.resolve_fallback(route)
                result = self._call(fb.model, req, fb)
                result.fallback_reason = e.reason
            resp = self.accounting.record(req, route, result, int((time.monotonic() - t0) * 1000))
            span.set_attributes(self._span_attrs(req, route, resp))
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

## Anthropic provider

```python
import anthropic

class AnthropicProvider:
    def __init__(self, timeout_s: float, max_retries: int = 2):
        self.client = anthropic.Anthropic(timeout=timeout_s, max_retries=max_retries)

    def complete(self, model: str, req: LLMRequest, route: Route) -> ProviderResult:
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
        if route.effort:
            kwargs.setdefault("output_config", {})["effort"] = route.effort
        try:
            if route.stream or (req.max_tokens or route.max_tokens) > 16000:
                with self.client.messages.stream(**kwargs) as s:
                    msg = s.get_final_message()
            else:
                msg = self.client.messages.create(**kwargs)
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
Opus 5 and Fable 5.1; do not send `thinking` or `temperature`. Haiku 4.5
takes no `effort`; the route sets it to null. Opus 5 and Fable 5.1 can
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
`llm_request_duration_seconds{feature,model}`.

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
`test_no_bodies_in_logs_by_default`, `test_refusal_raises_after_accounting`.
A laptop-only test `test_prompt_cache_hit` makes two identical calls and
asserts `cache_read_input_tokens > 0` on the second.

Makefile: `llm-audit` greps for call sites outside `llm/` and fails on
any; `llm-record` runs the recording tests with `RECORD_LLM=1`.
