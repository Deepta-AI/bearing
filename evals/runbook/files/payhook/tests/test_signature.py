import hashlib
import hmac
import json

from app import db, queue, server, signature


def sign(secret, body):
    return hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()


def test_current_or_previous_secret_verifies():
    body = b'{"id":"evt_1"}'
    assert signature.verify(body, sign("new", body), secret="new", previous="old")
    assert signature.verify(body, sign("old", body), secret="new", previous="old")
    assert not signature.verify(body, sign("other", body), secret="new", previous="old")


def test_bad_signature_is_stored_dead(monkeypatch):
    monkeypatch.setattr(signature.config, "WEBHOOK_SIGNING_SECRET", "new")
    monkeypatch.setattr(signature.config, "WEBHOOK_SIGNING_SECRET_PREVIOUS", "")
    conn = db.connect("sqlite://")
    body = json.dumps({"id": "evt_9", "type": "payment.succeeded", "data": {}}).encode()
    assert server.store(conn, body, sign("rotated", body), now=100) == 401
    assert queue.stats(conn, now=101)["dead_by_error"] == {"signature_invalid": 1}
