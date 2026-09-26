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
    stop_reason: str
    input_tokens: int
    output_tokens: int
    latency_ms: int


class LLMClient(Protocol):
    def complete(self, *, system: str, user: str, tag: str, max_tokens: int = 200) -> Response: ...


class RecordingMismatch(RuntimeError):
    """The request differs from the one that was recorded."""


def sha256(text: str) -> str:
    return hashlib.sha256(" ".join(text.split()).encode()).hexdigest()


class RecordedLLM:
    """Replays fixtures/recorded/<version>.jsonl keyed by ticket id (`tag`).

    Each row stores the sha256 of the (whitespace-normalised) system prompt it
    was recorded with; replaying for a different prompt raises, because the
    recorded answer says nothing about a prompt that was never sent.
    """

    def __init__(self, version: str, path: Path | None = None):
        path = path or ROOT / "fixtures" / "recorded" / f"{version}.jsonl"
        if not path.exists():
            raise FileNotFoundError(f"no recordings for prompt {version} at {path}")
        self.rows = {}
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.strip():
                row = json.loads(line)
                self.rows[row["id"]] = row

    def complete(self, *, system: str, user: str, tag: str, max_tokens: int = 200) -> Response:
        row = self.rows.get(tag)
        if row is None:
            raise RecordingMismatch(f"no recording for {tag}")
        if row["system_sha256"] != sha256(system):
            raise RecordingMismatch(f"{tag}: recorded with a different system prompt")
        return Response(row["text"], row["model"], row["stop_reason"],
                        row["input_tokens"], row["output_tokens"], row["latency_ms"])
