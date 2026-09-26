"""charge(): one card payment attempt at checkout."""

from app import flags
from app.gateway import Declined
from app.store import record_attempt


def charge(conn, gateway, order_id: str, amount_paise: int, card_token: str) -> str:
    flow = "3ds_v2" if flags.three_ds_v2() else "classic"
    try:
        if flow == "3ds_v2":
            ref = gateway.charge_3ds_v2(order_id, amount_paise, card_token)
        else:
            ref = gateway.charge(order_id, amount_paise, card_token)
    except Declined as e:
        record_attempt(conn, order_id, amount_paise, flow, "declined", e.code)
        raise
    record_attempt(conn, order_id, amount_paise, flow, "captured")
    return ref
