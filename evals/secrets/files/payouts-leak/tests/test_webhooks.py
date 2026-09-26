import hashlib
import hmac

import pytest

from payouts import webhooks

KEY = "test-key-not-a-secret"


def sign(body):
    return hmac.new(KEY.encode(), body, hashlib.sha256).hexdigest()


def test_valid_signature_applies_status():
    body = b'{"reference": "p1", "status": "paid"}'
    store = {}
    assert webhooks.handle(KEY, body, sign(body), store) == "paid"
    assert store == {"p1": "paid"}


def test_bad_signature_is_rejected():
    with pytest.raises(webhooks.BadSignature):
        webhooks.handle(KEY, b'{"reference": "p1", "status": "paid"}', "00", {})
