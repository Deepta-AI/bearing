import json
import os

PATH = "notes.json"


def load(path=PATH):
    if not os.path.exists(path):
        return []
    with open(path) as f:
        return json.load(f)


def add(text, path=PATH):
    notes = load(path)
    notes.append({"id": len(notes) + 1, "text": text})
    with open(path, "w") as f:
        json.dump(notes, f)
    return notes[-1]
