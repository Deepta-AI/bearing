import hashlib
import hmac


def parse(header):
    parts = dict(item.split("=", 1) for item in header.split(",") if "=" in item)
    return parts.get("t", ""), parts.get("v1", "")


def verify(secret, header, body):
    """True when header carries a valid v1 signature for the raw body."""
    t, v1 = parse(header)
    if not t or not v1:
        return False
    expected = hmac.new(secret.encode(), t.encode() + b"." + body, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, v1)
