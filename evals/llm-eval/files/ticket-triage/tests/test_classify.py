import json

import pytest

from triage.classify import TriageParseError, classify
from triage.llm import RecordedLLM, RecordingMismatch, Response
from triage import prompts


class OneShot:
    def __init__(self, text):
        self.text = text

    def complete(self, *, system, user, tag, max_tokens=200):
        return Response(self.text, "fake", "end_turn", 10, 5, 1)


def test_parses_category():
    t = {"id": "T-1", "subject": "Invoice", "body": "Charged twice"}
    assert classify(t, OneShot('{"category": "billing", "reason": "x"}')) == "billing"


def test_bad_json_raises():
    t = {"id": "T-1", "subject": "x", "body": "y"}
    with pytest.raises(TriageParseError):
        classify(t, OneShot('{"category": "bil'))


def test_recorded_client_replays_first_ticket():
    t = json.loads(open("data/tickets.jsonl").readline())
    assert classify(t, RecordedLLM(prompts.PROMPT_VERSION))


def test_recorded_client_refuses_other_prompt():
    c = RecordedLLM(prompts.PROMPT_VERSION)
    with pytest.raises(RecordingMismatch):
        c.complete(system="a different prompt", user="u", tag="T-1001")
