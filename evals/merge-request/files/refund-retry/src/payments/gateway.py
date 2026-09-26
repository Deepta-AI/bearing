"""Card gateway client."""

import json
import urllib.error
import urllib.request


class GatewayTimeout(Exception):
    """The gateway did not answer in time; the call may or may not have applied."""


class GatewayDeclined(Exception):
    """The gateway refused the operation; retrying will not help."""


class HttpGateway:
    def __init__(self, base_url, timeout_s):
        self.base_url = base_url.rstrip("/")
        self.timeout_s = timeout_s

    def refund(self, order_id, amount_paise, idempotency_key):
        body = json.dumps({"order_id": order_id, "amount": amount_paise}).encode()
        req = urllib.request.Request(
            f"{self.base_url}/refunds",
            data=body,
            headers={"Idempotency-Key": idempotency_key, "Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=self.timeout_s) as resp:
                return json.load(resp)
        except TimeoutError as e:
            raise GatewayTimeout(str(e)) from e
        except urllib.error.HTTPError as e:
            if e.code in (400, 402, 409, 422):
                raise GatewayDeclined(f"HTTP {e.code}") from e
            raise GatewayTimeout(f"HTTP {e.code}") from e
