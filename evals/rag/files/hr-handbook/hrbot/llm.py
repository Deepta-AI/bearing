"""Model client interface. Tests use FakeLLM; nothing here calls a network."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Callable, Protocol


@dataclass
class Completion:
    text: str
    model: str
    stop_reason: str = "end_turn"


class LLMClient(Protocol):
    def complete(self, *, system: str, user: str, max_tokens: int = 1024) -> Completion: ...


@dataclass
class FakeLLM:
    """Returns `reply`, or `responder(system, user)` when given. Records calls."""

    reply: str = "canned answer"
    responder: Callable[[str, str], str] | None = None
    calls: list[dict] = field(default_factory=list)

    def complete(self, *, system: str, user: str, max_tokens: int = 1024) -> Completion:
        self.calls.append({"system": system, "user": user})
        text = self.responder(system, user) if self.responder else self.reply
        return Completion(text=text, model="fake-model")
