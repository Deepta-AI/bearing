"""Provider webhook signatures: hex HMAC-SHA256 of the raw body.

During a provider secret rotation both secrets are valid: set the new one as
WEBHOOK_SIGNING_SECRET and keep the old one as WEBHOOK_SIGNING_SECRET_PREVIOUS
until the provider confirms the rotation is complete.
"""

import hashlib
import hmac

from app import config


def _sign(secret, body):
    return hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()


def verify(body, signature, secret=None, previous=None):
    secret = config.WEBHOOK_SIGNING_SECRET if secret is None else secret
    previous = config.WEBHOOK_SIGNING_SECRET_PREVIOUS if previous is None else previous
    for s in (secret, previous):
        if s and hmac.compare_digest(_sign(s, body), signature or ""):
            return True
    return False
