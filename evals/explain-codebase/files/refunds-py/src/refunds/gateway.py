import base64
import json
import os
import urllib.request


class Razorpay:
    def __init__(self, base_url: str):
        self.base_url = base_url
        key = f"{os.environ.get('RAZORPAY_KEY_ID', '')}:{os.environ.get('RAZORPAY_KEY_SECRET', '')}"
        self.auth = "Basic " + base64.b64encode(key.encode()).decode()

    def refund(self, payment_id: str, amount_paise: int) -> dict:
        req = urllib.request.Request(
            f"{self.base_url}/payments/{payment_id}/refund",
            data=json.dumps({"amount": amount_paise}).encode(),
            headers={"Authorization": self.auth, "Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.load(resp)
