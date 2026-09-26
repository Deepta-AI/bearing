"""Signed session cookies."""

import base64
import hashlib
import hmac


def sign(secret, value):
    mac = hmac.new(secret.encode(), value.encode(), hashlib.sha256).digest()
    return value + "." + base64.urlsafe_b64encode(mac).decode().rstrip("=")


def unsign(secret, cookie):
    value, _, _mac = cookie.rpartition(".")
    if not value or not hmac.compare_digest(sign(secret, value), cookie):
        return None
    return value
