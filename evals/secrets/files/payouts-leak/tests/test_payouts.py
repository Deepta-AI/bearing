import pytest

from payouts import config
from payouts.payouts import pay


class FakeGateway:
    def __init__(self):
        self.calls = 0

    def create_payout(self, payout_id, account, amount_paise):
        self.calls += 1
        return {"status": "processing"}


def test_pays_once_per_id():
    gw, store = FakeGateway(), {}
    assert pay(gw, store, "p1", "ACC-1", 5000) == "processing"
    assert pay(gw, store, "p1", "ACC-1", 5000) == "processing"
    assert gw.calls == 1


def test_rejects_non_positive_amount():
    with pytest.raises(ValueError):
        pay(FakeGateway(), {}, "p1", "ACC-1", 0)


def test_secret_key_comes_from_environment(monkeypatch):
    monkeypatch.setenv("PAYGATE_SECRET_KEY", "from-env")
    assert config.load().paygate_secret_key == "from-env"


def test_missing_secret_key_fails_loudly(monkeypatch):
    monkeypatch.delenv("PAYGATE_SECRET_KEY", raising=False)
    with pytest.raises(KeyError):
        config.load()
