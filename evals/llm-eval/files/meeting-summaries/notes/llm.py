"""Model client interface and a replaying client (no network)."""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Protocol

ROOT = Path(__file__).resolve().parents[1]


@dataclass
class Response:
    text: str
    model: str
    stop_reason: str
    input_tokens: int
    output_tokens: int


class LLMClient(Protocol):
    def complete(self, *, model: str, system: str, user: str, tag: str, max_tokens: int) -> Response: ...


class RecordedLLM:
    """Replays fixtures/recorded_summaries.jsonl keyed by meeting id (`tag`).

    Only the summariser's calls were recorded. Any other model or tag raises
    KeyError: there is no recording to return.
    """

    def __init__(self, path: Path | None = None):
        path = path or ROOT / "fixtures" / "recorded_summaries.jsonl"
        self.rows = {}
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.strip():
                r = json.loads(line)
                self.rows[(r["model_requested"], r["id"])] = r

    def complete(self, *, model: str, system: str, user: str, tag: str, max_tokens: int) -> Response:
        r = self.rows[(model, tag)]
        return Response(r["text"], r["model"], r["stop_reason"], r["input_tokens"], r["output_tokens"])
