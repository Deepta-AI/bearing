"""Inbound PayGate webhooks: verify the signature, then apply the status."""

import hashlib
import hmac
import json


class BadSignature(Exception):
    pass


def verify(secret_key, raw_body, signature):
    expected = hmac.new(secret_key.encode(), raw_body, hashlib.sha256).hexdigest()
    if not hmac.compare_digest(expected, signature or ""):
        raise BadSignature("webhook signature does not match")


def handle(secret_key, raw_body, signature, store):
    verify(secret_key, raw_body, signature)
    event = json.loads(raw_body)
    store[event["reference"]] = event["status"]
    return event["status"]
