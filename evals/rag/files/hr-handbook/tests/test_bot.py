from hrbot.bot import Reply, answer
from hrbot.llm import FakeLLM


def test_answer_returns_reply():
    r = answer("How many leave days do I get?", FakeLLM())
    assert isinstance(r, Reply)
    assert r.text
