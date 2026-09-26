"""Charge a card through the payment gateway."""


class GatewayUnavailable(Exception):
    pass


def charge(client, invoice_id, amount_paise, attempts=3):
    key = f"invoice:{invoice_id}"
    for attempt in range(1, attempts + 1):
        resp = client.post("/charges", {"amount": amount_paise}, idempotency_key=key)
        if resp["status"] != 503:
            return resp
    raise GatewayUnavailable(f"gateway returned 503 {attempts} times for {invoice_id}")
