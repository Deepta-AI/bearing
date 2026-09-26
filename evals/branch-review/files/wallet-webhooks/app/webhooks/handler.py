import json
import logging
import time

from app import settings, wallet
from app.webhooks import dedupe, signature

log = logging.getLogger("wallet.webhooks")


def handle(conn, headers, body):
    """POST /webhooks/provider. Returns the HTTP status to send back."""
    sig = headers.get("X-Provider-Signature")
    if sig is not None:
        if not signature.verify(settings.WEBHOOK_SECRET, sig, body):
            log.warning("webhook rejected: bad signature")
            return 401
        t, _ = signature.parse(sig)
        if int(t) < time.time() - settings.REPLAY_WINDOW_SECONDS:
            log.warning("webhook rejected: stale timestamp")
            return 401

    event = json.loads(body)
    log.info("webhook received: %s", event)

    if dedupe.seen(conn, event["id"]):
        return 200

    data = event["data"]
    if event["type"] == "payment.succeeded":
        wallet.credit(conn, data["customer_id"], data["amount"])
    elif event["type"] == "payment.refunded":
        wallet.debit(conn, data["customer_id"], data["amount"])
    else:
        log.error("unknown webhook type %s", event["type"])
        return 400

    dedupe.mark(conn, event["id"])
    conn.commit()
    return 200
