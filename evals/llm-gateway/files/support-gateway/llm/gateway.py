"""The one place the service calls a model."""

import os
import time

from llm import accounting
from llm.routing import Routing
from llm.types import FeatureDisabled, LLMRequest, LLMResponse


class Gateway:
    def __init__(self, routing: Routing, providers: dict):
        self.routing = routing
        self.providers = providers

    def complete(self, req: LLMRequest) -> LLMResponse:
        route = self.routing.route(req.feature)
        if not route.enabled or os.environ.get(f"LLM_KILL_{req.feature.upper()}") == "1":
            raise FeatureDisabled(req.feature)
        provider = self.providers[route.provider]
        t0 = time.monotonic()
        result = provider.complete(route.model, req, route)
        latency_ms = int((time.monotonic() - t0) * 1000)
        cost = accounting.cost_usd(self.routing.prices[route.model], req, route, result)
        accounting.record(req, route, result, cost, latency_ms)
        return LLMResponse(
            text=result.text,
            model=route.model,
            stop_reason=result.stop_reason,
            usage=result.usage,
            cost_usd=cost,
            latency_ms=latency_ms,
        )


_default = None


def default_gateway() -> Gateway:
    global _default
    if _default is None:
        from llm.providers.anthropic_provider import AnthropicProvider

        _default = Gateway(Routing(), {"anthropic": AnthropicProvider()})
    return _default
