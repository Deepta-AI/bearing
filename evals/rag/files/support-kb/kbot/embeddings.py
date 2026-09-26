"""Embedding interface.

Production will use a hosted or self-hosted embedding model (not chosen yet).
Tests and local runs use HashingEmbedder: deterministic, no network, stdlib
only. It is a hashed bag of words, so it behaves more like a lexical matcher
than a semantic model; do not read quality numbers from it as if it were one.
"""

from __future__ import annotations

import hashlib
import math
import re
from typing import Protocol, Sequence

TOKEN = re.compile(r"[a-z0-9][a-z0-9\-]*")


class Embedder(Protocol):
    dims: int

    def embed(self, texts: Sequence[str]) -> list[list[float]]: ...


class HashingEmbedder:
    """Signed feature hashing into `dims` buckets, L2 normalised."""

    def __init__(self, dims: int = 256):
        self.dims = dims
        self.calls = 0

    def _one(self, text: str) -> list[float]:
        vec = [0.0] * self.dims
        for tok in TOKEN.findall(text.lower()):
            h = int.from_bytes(hashlib.sha256(tok.encode()).digest()[:8], "big")
            idx = h % self.dims
            sign = 1.0 if (h >> 63) & 1 else -1.0
            vec[idx] += sign
        norm = math.sqrt(sum(v * v for v in vec)) or 1.0
        return [v / norm for v in vec]

    def embed(self, texts: Sequence[str]) -> list[list[float]]:
        self.calls += 1
        return [self._one(t) for t in texts]


def cosine(a: Sequence[float], b: Sequence[float]) -> float:
    return sum(x * y for x, y in zip(a, b))
