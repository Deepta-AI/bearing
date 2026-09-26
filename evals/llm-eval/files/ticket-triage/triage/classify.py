from __future__ import annotations

import json

from . import prompts
from .llm import LLMClient


class TriageParseError(ValueError):
    pass


def classify(ticket: dict, client: LLMClient) -> str:
    """Return the category the model picked for `ticket`."""
    resp = client.complete(system=prompts.SYSTEM, user=prompts.user_message(ticket), tag=ticket["id"])
    try:
        data = json.loads(resp.text)
    except json.JSONDecodeError as e:
        raise TriageParseError(f"{ticket['id']}: reply is not JSON: {resp.text!r}") from e
    return data["category"]
