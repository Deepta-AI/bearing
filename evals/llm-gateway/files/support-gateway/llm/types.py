from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True)
class LLMRequest:
    feature: str
    tenant_id: str
    messages: list[dict[str, Any]]
    system: str | None = None
    max_tokens: int | None = None


@dataclass(frozen=True)
class Usage:
    input_tokens: int
    output_tokens: int


@dataclass
class ProviderResult:
    text: str
    model: str
    stop_reason: str
    usage: Usage
    request_id: str | None = None


@dataclass
class LLMResponse:
    text: str
    model: str
    stop_reason: str
    usage: Usage
    cost_usd: float
    latency_ms: int
    extra: dict[str, Any] = field(default_factory=dict)


class FeatureDisabled(Exception):
    pass


class ProviderUnavailable(Exception):
    def __init__(self, reason: str):
        super().__init__(reason)
        self.reason = reason
