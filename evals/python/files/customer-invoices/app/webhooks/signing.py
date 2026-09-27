"""Provider signature check: HMAC-SHA256 of the raw body (docs/provider-webhooks.md)."""

import hashlib
import hmac


def verify_signature(raw_body: bytes, header: str | None, secret: str) -> bool:
    """True when header is 'sha256=<hex>' of raw_body under secret."""
    if not header or not header.startswith("sha256="):
        return False
    expected = hmac.new(secret.encode(), raw_body, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, header.removeprefix("sha256="))
