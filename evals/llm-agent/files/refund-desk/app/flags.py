"""Runtime flags. Ops change var/flags.json on the host; every read goes to the file."""

import json
import os

FLAGS_PATH = os.environ.get("REFUND_DESK_FLAGS", os.path.join("var", "flags.json"))


def is_on(name: str, default: bool = False, path: str | None = None) -> bool:
    try:
        with open(path or FLAGS_PATH, encoding="utf-8") as f:
            return bool(json.load(f).get(name, default))
    except (OSError, ValueError):
        return default
