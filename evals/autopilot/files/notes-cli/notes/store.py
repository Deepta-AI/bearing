import json
import os

PATH = "notes.json"


def load(path=PATH):
    """The stored list exactly as it is on disk, for writers."""
    if not os.path.exists(path):
        return []
    with open(path) as f:
        return json.load(f)


def notes(path=PATH):
    """Every note as {"id", "text"}, in stored order, for readers.

    notes.json written by 0.1 held bare strings; such an entry takes its
    position as its id.
    """
    out = []
    for i, n in enumerate(load(path), 1):
        out.append({"id": i, "text": n} if isinstance(n, str) else n)
    return out


def add(text, path=PATH):
    stored = load(path)
    stored.append({"id": len(stored) + 1, "text": text})
    with open(path, "w") as f:
        json.dump(stored, f)
    return stored[-1]
