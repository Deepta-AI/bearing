"""Model access. Blocks follow the Messages API shape:
{"type": "text", "text"} and {"type": "tool_use", "id", "name", "input"}.
"""

from dataclasses import dataclass
from typing import Protocol

MODEL = "claude-sonnet-5"


@dataclass
class ModelResponse:
    content: list[dict]
    stop_reason: str  # end_turn | tool_use | max_tokens | refusal
    input_tokens: int = 0
    output_tokens: int = 0


class ModelClient(Protocol):
    def create(self, *, model: str, system: str, messages: list[dict], tools: list[dict], max_tokens: int) -> ModelResponse: ...
