from loyalty.members import MemberStore
from loyalty.pos_webhook import handle


# REQ-002: 1 point per Rs 10 of a completed bill.
def test_member_earns_on_completed_sale():
    store = MemberStore()
    store.enrol("+919800000001", "Asha")
    r = handle(
        {"type": "sale.completed", "sale_id": "s1", "member_phone": "+919800000001", "amount_paise": 18000},
        store,
    )
    assert r == {"status": "ok", "earned": 18}
    assert store.get("+919800000001").points == 18


def test_non_member_sale_is_ignored():
    r = handle({"type": "sale.completed", "sale_id": "s2", "member_phone": "+919800000009", "amount_paise": 5000}, MemberStore())
    assert r["status"] == "ignored"


def test_refund_is_not_handled_yet():
    r = handle({"type": "sale.refunded", "sale_id": "s1"}, MemberStore())
    assert r["reason"] == "refunds not handled"
