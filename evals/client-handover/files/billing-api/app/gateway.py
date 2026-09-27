"""Payment gateway client."""

import hmac
import hashlib
import os

import httpx

BASE_URL = os.environ.get("PAYMENT_GATEWAY_URL", "https://sandbox.pay.example.com")


def create_payment_link(invoice_id: str, amount_paise: int) -> str:
    r = httpx.post(
        f"{BASE_URL}/v1/links",
        headers={"authorization": f"Bearer {os.environ['PAYMENT_GATEWAY_KEY']}"},
        json={"reference": invoice_id, "amount": amount_paise, "currency": "INR"},
        timeout=10,
    )
    r.raise_for_status()
    return r.json()["url"]


def verify_webhook(body: bytes, signature: str) -> bool:
    secret = os.environ["PAYMENT_WEBHOOK_SECRET"].encode()
    want = hmac.new(secret, body, hashlib.sha256).hexdigest()
    return hmac.compare_digest(want, signature)
