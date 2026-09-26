"""Prototype answer step (not used by the widget yet).

Pastes the top three whole articles into the prompt and asks for an answer.
"""

from __future__ import annotations

from .llm import LLMClient
from .search import KB_ROOT, search


def answer(question: str, client: LLMClient) -> str:
    paths = search(question)
    context = "\n\n".join((KB_ROOT / p).read_text(encoding="utf-8") for p in paths)
    system = f"You are Ledgerleaf's friendly support assistant. Use this help centre content:\n{context}"
    return client.complete(system=system, user=question).text
