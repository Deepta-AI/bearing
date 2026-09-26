from pathlib import Path

from notes.llm import RecordedLLM
from notes.summarise import summarise


def test_replays_recorded_summary():
    t = Path("data/transcripts/m01.txt").read_text()
    s = summarise("m01", t, RecordedLLM())
    assert "Decisions" in s.text
    assert s.model.startswith("claude-")
