from dataclasses import dataclass
from typing import Protocol

MODEL = "claude-sonnet-5"


@dataclass
class ModelResponse:
    text: str
    stop_reason: str = "end_turn"  # end_turn | max_tokens | refusal


class ModelClient(Protocol):
    def create(self, *, model: str, system: str, messages: list[dict], max_tokens: int) -> ModelResponse: ...
