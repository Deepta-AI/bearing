import pytest

from llm.gateway import Gateway
from llm.providers.fake import FakeProvider
from llm.routing import Routing, UnknownFeature
from llm.types import FeatureDisabled, LLMRequest, ProviderResult, Usage
from app.tickets import classify_ticket


def gw(script=None):
    fake = FakeProvider(script)
    return Gateway(Routing(), {"anthropic": fake}), fake


def req(feature="ticket_classify"):
    return LLMRequest(feature=feature, tenant_id="t1", messages=[{"role": "user", "content": "hi"}])


def test_route_picks_tier_model():
    g, fake = gw()
    g.complete(req("ticket_classify"))
    g.complete(req("reply_draft"))
    assert [m for m, _ in fake.calls] == ["claude-haiku-4-5", "claude-sonnet-5"]


def test_unknown_feature_fails_the_call():
    g, _ = gw()
    with pytest.raises(UnknownFeature):
        g.complete(req("nope"))


def test_kill_switch_before_provider(monkeypatch):
    g, fake = gw()
    monkeypatch.setenv("LLM_KILL_REPLY_DRAFT", "1")
    with pytest.raises(FeatureDisabled):
        g.complete(req("reply_draft"))
    assert fake.calls == []


def test_classify_ticket_uses_gateway():
    g, _ = gw([ProviderResult("technical", "claude-haiku-4-5", "end_turn", Usage(40, 1))])
    assert classify_ticket("t1", "the app crashes", gateway=g) == "technical"
