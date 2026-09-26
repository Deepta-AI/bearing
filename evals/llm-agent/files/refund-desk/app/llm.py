"""The one interface for model calls in this service.

Production passes AnthropicModel (app/llm_anthropic.py). Tests pass a
scripted fake from tests/fakes.py. Response blocks follow the Messages API
shape: {"type": "text", "text": ...} and
{"type": "tool_use", "id": ..., "name": ..., "input": {...}}. Tool results go
back as a user message of {"type": "tool_result", "tool_use_id": ...,
"content": str, "is_error": bool} blocks.
"""

from dataclasses import dataclass, field
from typing import Protocol

DEFAULT_MODEL = "claude-sonnet-5"

# USD per million tokens: (input, output, cache read). Finance sheet, Sep 2026.
PRICES = {
    "claude-opus-5": (5.00, 25.00, 0.50),
    "claude-sonnet-5": (3.00, 15.00, 0.30),
    "claude-haiku-4-5": (1.00, 5.00, 0.10),
}


@dataclass
class Usage:
    input_tokens: int
    output_tokens: int
    cache_read_input_tokens: int = 0


@dataclass
class ModelResponse:
    content: list[dict]
    stop_reason: str  # end_turn | tool_use | max_tokens | refusal | pause_turn
    usage: Usage
    request_id: str = ""
    model: str = DEFAULT_MODEL
    extra: dict = field(default_factory=dict)


class ModelClient(Protocol):
    def create(
        self,
        *,
        model: str,
        system: str,
        messages: list[dict],
        tools: list[dict],
        max_tokens: int,
    ) -> ModelResponse: ...


def cost_usd(model: str, usage: Usage) -> float:
    p_in, p_out, p_cache = PRICES[model]
    return (
        usage.input_tokens * p_in
        + usage.output_tokens * p_out
        + usage.cache_read_input_tokens * p_cache
    ) / 1_000_000
