"""Model client interface.

Production wires an SDK client behind LLMClient. Tests use FakeLLM, which
records every call and returns a canned answer, so no test needs a key.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Protocol


@dataclass
class Completion:
    text: str
    model: str
    stop_reason: str = "end_turn"
    input_tokens: int = 0
    output_tokens: int = 0


class LLMClient(Protocol):
    def complete(self, *, system: str, user: str, max_tokens: int = 1024) -> Completion: ...


@dataclass
class FakeLLM:
    reply: str = "This is a canned answer."
    model: str = "fake-model"
    calls: list[dict] = field(default_factory=list)

    def complete(self, *, system: str, user: str, max_tokens: int = 1024) -> Completion:
        self.calls.append({"system": system, "user": user, "max_tokens": max_tokens})
        return Completion(text=self.reply, model=self.model,
                          input_tokens=len(system.split()) + len(user.split()),
                          output_tokens=len(self.reply.split()))
