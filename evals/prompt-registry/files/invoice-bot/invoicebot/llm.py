"""Model client interface and a replaying client for offline runs."""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Protocol

ROOT = Path(__file__).resolve().parents[1]


@dataclass
class Response:
    text: str
    model: str
    stop_reason: str = "end_turn"


class LLMClient(Protocol):
    def complete(self, *, model: str, system: str, user: str, tag: str, max_tokens: int) -> Response: ...


class RecordingMismatch(RuntimeError):
    pass


def prompt_hash(text: str) -> str:
    """sha256 of the text with runs of whitespace collapsed."""
    return hashlib.sha256(" ".join(text.split()).encode()).hexdigest()


class RecordedLLM:
    """Replays tests/recorded/extract.jsonl keyed by invoice id (`tag`).

    Every row holds the hash of the system prompt it was recorded with. A
    request with a different system prompt raises RecordingMismatch: the
    recording says nothing about a prompt that was never sent.
    """

    def __init__(self, path: Path | None = None):
        path = path or ROOT / "tests" / "recorded" / "extract.jsonl"
        self.rows = {}
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.strip():
                r = json.loads(line)
                self.rows[r["id"]] = r

    def complete(self, *, model: str, system: str, user: str, tag: str, max_tokens: int) -> Response:
        r = self.rows.get(tag)
        if r is None:
            raise RecordingMismatch(f"no recording for {tag}")
        if r["system_sha256"] != prompt_hash(system):
            raise RecordingMismatch(f"{tag}: system prompt differs from the recorded one")
        if r["model"] != model:
            raise RecordingMismatch(f"{tag}: recorded with {r['model']}, asked for {model}")
        return Response(r["text"], r["model"], r["stop_reason"])
