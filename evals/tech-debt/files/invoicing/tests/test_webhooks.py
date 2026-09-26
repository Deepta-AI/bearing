import hashlib
import hmac

import pytest

from invoicing.webhooks import verify


def sign(secret, body):
    return hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()


def test_accepts_valid_signature():
    assert verify("s3", b"{}", sign("s3", b"{}"))


@pytest.mark.quarantine
def test_rejects_tampered_body():
    assert not verify("s3", b'{"amount": 1}', sign("s3", b"{}"))
