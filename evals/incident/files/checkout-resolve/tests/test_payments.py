import pytest

from app.gateway import Declined, Gateway
from app.payments import charge
from app.store import connect


def fake_post(result="captured", code=None):
    calls = []

    def post(url, body):
        calls.append((url, body))
        if result == "captured":
            return 200, {"result": "captured", "reference": "ch_1"}
        return 402, {"result": "declined", "decline_code": code}

    return post, calls


def rows(conn):
    return conn.execute("SELECT flow, status, decline_code FROM payment_attempts").fetchall()


def test_captured_attempt_is_recorded(monkeypatch):
    monkeypatch.setenv("PAYMENTS_3DS_V2_ENABLED", "false")
    post, calls = fake_post()
    conn = connect()
    assert charge(conn, Gateway("https://gw.test", post), "o1", 49900, "tok") == "ch_1"
    assert calls[0][0] == "https://gw.test/charges"
    assert rows(conn) == [("classic", "captured", None)]


def test_declined_attempt_keeps_the_code(monkeypatch):
    monkeypatch.setenv("PAYMENTS_3DS_V2_ENABLED", "false")
    post, _ = fake_post("declined", "insufficient_funds")
    conn = connect()
    with pytest.raises(Declined):
        charge(conn, Gateway("https://gw.test", post), "o2", 49900, "tok")
    assert rows(conn) == [("classic", "declined", "insufficient_funds")]


def test_three_ds_flag_routes_to_authenticated_charge(monkeypatch):
    monkeypatch.setenv("PAYMENTS_3DS_V2_ENABLED", "true")
    post, calls = fake_post()
    conn = connect()
    charge(conn, Gateway("https://gw.test", post), "o3", 100, "tok")
    assert calls[0][0] == "https://gw.test/charges/authenticated"
    assert rows(conn) == [("3ds_v2", "captured", None)]
