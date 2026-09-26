"""Card gateway client. The HTTP transport is injected so tests never call out."""

import json


class Declined(Exception):
    def __init__(self, code: str):
        super().__init__(code)
        self.code = code


class Gateway:
    def __init__(self, base_url: str, post):
        self.base_url = base_url.rstrip("/")
        self._post = post  # post(url, body_dict) -> (status, body_dict)

    def _call(self, path: str, body: dict) -> str:
        status, resp = self._post(self.base_url + path, body)
        if status == 200 and resp.get("result") == "captured":
            return resp["reference"]
        raise Declined(resp.get("decline_code", "unknown"))

    def charge(self, order_id: str, amount_paise: int, card_token: str) -> str:
        return self._call("/charges", {"order": order_id, "amount": amount_paise, "card": card_token})

    def charge_3ds_v2(self, order_id: str, amount_paise: int, card_token: str) -> str:
        body = {"order": order_id, "amount": amount_paise, "card": card_token,
                "authentication": {"version": "2.2", "challenge": "if_required"}}
        return self._call("/charges/authenticated", body)


def dumps(body: dict) -> str:
    return json.dumps(body, sort_keys=True)
