"""One llm_call log line per call; the finance report sums cost_usd."""

import json
import logging

from llm.routing import Price, Route
from llm.types import LLMRequest, ProviderResult

log = logging.getLogger("llm")


def cost_usd(price: Price, req: LLMRequest, route: Route, result: ProviderResult) -> float:
    out_tokens = req.max_tokens or route.max_tokens
    return (result.usage.input_tokens * price.input_per_m + out_tokens * price.output_per_m) / 1_000_000


def record(req: LLMRequest, route: Route, result: ProviderResult, cost: float, latency_ms: int) -> None:
    log.info(
        "llm_call %s",
        json.dumps(
            {
                "feature": req.feature,
                "tenant_id": req.tenant_id,
                "model": route.model,
                "input_tokens": result.usage.input_tokens,
                "output_tokens": result.usage.output_tokens,
                "cost_usd": round(cost, 8),
                "latency_ms": latency_ms,
                "stop_reason": result.stop_reason,
                "request_id": result.request_id,
            }
        ),
    )
