"""Verify the gateway's webhook signature."""

import hashlib
import hmac


def verify(secret, body, signature):
    expected = hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, signature)
