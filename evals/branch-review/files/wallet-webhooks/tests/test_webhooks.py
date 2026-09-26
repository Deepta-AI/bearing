import hashlib
import hmac
import json
import time

import pytest

from app import db, settings, wallet
from app.webhooks import handler


def signed(body, secret=None, t=None):
    secret = secret or settings.WEBHOOK_SECRET
    t = str(t or int(time.time()))
    v1 = hmac.new(secret.encode(), t.encode() + b"." + body, hashlib.sha256).hexdigest()
    return {"X-Provider-Signature": f"t={t},v1={v1}"}


def event(event_id, etype="payment.succeeded", amount=5000):
    return json.dumps(
        {
            "id": event_id,
            "type": etype,
            "data": {"customer_id": "c1", "amount": amount, "email": "a@example.com", "phone": "+910000000000"},
        }
    ).encode()


@pytest.fixture
def conn():
    return db.connect(":memory:")


def test_payment_succeeded_credits_wallet(conn):
    body = event("evt_1")
    assert handler.handle(conn, signed(body), body) == 200
    assert wallet.balance(conn, "c1") == 5000


def test_bad_signature_is_rejected(conn):
    body = event("evt_2")
    assert handler.handle(conn, signed(body, secret="wrong"), body) == 401
    assert wallet.balance(conn, "c1") == 0


def test_stale_delivery_is_rejected(conn):
    body = event("evt_4")
    assert handler.handle(conn, signed(body, t=int(time.time()) - 86400), body) == 401
    assert wallet.balance(conn, "c1") == 0


def test_same_event_twice_credits_once(conn):
    body = event("evt_3")
    handler.handle(conn, signed(body), body)
    handler.handle(conn, signed(body), body)
    assert wallet.balance(conn, "c1") == 5000
