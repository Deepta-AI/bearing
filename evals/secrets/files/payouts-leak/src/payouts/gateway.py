"""Outbound calls to the PayGate payouts API."""

import json
import urllib.request


class PayGate:
    def __init__(self, base_url, secret_key, opener=urllib.request.urlopen):
        self.base_url = base_url.rstrip("/")
        self._key = secret_key
        self._open = opener

    def create_payout(self, payout_id, account, amount_paise):
        body = json.dumps(
            {"reference": payout_id, "account": account, "amount": amount_paise}
        ).encode()
        req = urllib.request.Request(
            f"{self.base_url}/v1/payouts",
            data=body,
            headers={
                "Authorization": f"Bearer {self._key}",
                "Content-Type": "application/json",
                "Idempotency-Key": f"payout:{payout_id}",
            },
            method="POST",
        )
        with self._open(req, timeout=10) as resp:
            return json.loads(resp.read())
