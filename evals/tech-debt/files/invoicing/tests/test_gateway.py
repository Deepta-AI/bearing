import pytest

from invoicing.gateway import GatewayUnavailable, charge


class FakeClient:
    def __init__(self, statuses):
        self.statuses = list(statuses)
        self.keys = []

    def post(self, path, body, idempotency_key):
        self.keys.append(idempotency_key)
        return {"status": self.statuses.pop(0)}


def test_charge_succeeds():
    assert charge(FakeClient([200]), "INV-1", 5000)["status"] == 200


def test_retries_503_with_same_key():
    c = FakeClient([503, 503, 200])
    assert charge(c, "INV-2", 5000)["status"] == 200
    assert c.keys == ["invoice:INV-2"] * 3


def test_gives_up_after_three():
    with pytest.raises(GatewayUnavailable):
        charge(FakeClient([503, 503, 503]), "INV-3", 5000)
