"""Functions the model can call. The loop looks them up by name."""

import json
import logging

log = logging.getLogger("bot.tools")

_FAQ = {
    "delivery": "Orders ship within 2 working days. Metro cities get delivery in 3 to 5 days.",
    "returns": "You can return most items within 10 days of delivery from the Orders tab.",
    "payment": "We accept UPI, cards and net banking. Cash on delivery is available under Rs 5,000.",
}
_cache: dict[str, str] = {}

HANDOFF_QUEUE: list[dict] = []


def get_faq(topic: str) -> dict:
    """Answer for a FAQ topic: delivery, returns or payment."""
    if topic not in _cache:
        _cache[topic] = _FAQ.get(topic, "")
    return {"topic": topic, "answer": _cache[topic]}


def escalate_to_human(summary: str) -> dict:
    """Hand the conversation to a support person."""
    HANDOFF_QUEUE.append({"summary": summary})
    return {"status": "queued", "position": len(HANDOFF_QUEUE)}


def purge_faq_cache() -> dict:
    """Admin: called by the nightly job after the FAQ is edited."""
    _cache.clear()
    return {"status": "purged"}


SCHEMAS = [
    {
        "name": "get_faq",
        "description": "Get the FAQ answer for a topic.",
        "input_schema": {"type": "object", "properties": {"topic": {"type": "string"}}},
    },
    {
        "name": "escalate_to_human",
        "description": "Escalate to a human agent.",
        "input_schema": {"type": "object", "properties": {"summary": {"type": "string"}}},
    },
]


def dumps(value) -> str:
    return json.dumps(value, default=str)
