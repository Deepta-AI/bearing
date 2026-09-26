from __future__ import annotations

from dataclasses import dataclass

from .llm import LLMClient

MODEL = "claude-sonnet-5"
MAX_TOKENS = 400

SYSTEM = """You summarise internal product meetings for the team's Slack.
Write three sections: Decisions, Action items, Open questions.
Action items are "- <owner>: <task> (due <date>)" or "(no date)".
Only use owners who spoke in the meeting. Keep it under 180 words."""


@dataclass
class Summary:
    meeting_id: str
    text: str
    model: str
    stop_reason: str
    input_tokens: int
    output_tokens: int


def summarise(meeting_id: str, transcript: str, client: LLMClient) -> Summary:
    r = client.complete(model=MODEL, system=SYSTEM, user=transcript, tag=meeting_id, max_tokens=MAX_TOKENS)
    return Summary(meeting_id, r.text, r.model, r.stop_reason, r.input_tokens, r.output_tokens)
