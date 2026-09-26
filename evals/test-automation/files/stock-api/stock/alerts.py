import json
import urllib.request

from . import config


def send_low_stock(sku, qty):
    """Posts a low stock alert to the operations webhook."""
    body = json.dumps({"type": "low_stock", "sku": sku, "qty": qty}).encode()
    req = urllib.request.Request(
        config.ALERT_WEBHOOK_URL,
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=5) as resp:
        resp.read()
