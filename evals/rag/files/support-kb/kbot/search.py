"""Current widget search: substring match over whole articles.

Returns article paths only. No ranking beyond hit count, no passages, no
citations. Kept until the replacement is measured.
"""

from __future__ import annotations

from pathlib import Path

KB_ROOT = Path(__file__).resolve().parents[1] / "data" / "kb"


def search(query: str, root: Path = KB_ROOT, limit: int = 3) -> list[str]:
    words = [w for w in query.lower().split() if len(w) > 2]
    scored = []
    for path in sorted(root.rglob("*.md")):
        text = path.read_text(encoding="utf-8").lower()
        hits = sum(text.count(w) for w in words)
        if hits:
            scored.append((hits, str(path.relative_to(root))))
    scored.sort(key=lambda t: (-t[0], t[1]))
    return [p for _, p in scored[:limit]]
