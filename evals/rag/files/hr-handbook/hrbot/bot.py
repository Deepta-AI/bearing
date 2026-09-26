"""The #ask-hr bot. Placeholder until it can answer from the handbook."""

from __future__ import annotations

from dataclasses import dataclass, field

from .llm import LLMClient


@dataclass
class Reply:
    text: str
    sources: list[str] = field(default_factory=list)


def answer(question: str, client: LLMClient) -> Reply:
    return Reply(text="Please ask the HR team in #ask-hr-humans.")
