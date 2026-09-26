"""Handles events posted by the till (POS) system.

The POS sends sale.completed when a bill is paid and sale.refunded when a
bill is refunded in full at the counter. Amounts are in paise.
"""

POINTS_PER_RUPEES = 10  # placeholder until the PRD fixes the earn rule


def handle(event, store):
    kind = event.get("type")
    if kind == "sale.completed":
        member = store.get(event.get("member_phone"))
        if member is None:
            return {"status": "ignored", "reason": "not a member"}
        rupees = event["amount_paise"] // 100
        earned = rupees // POINTS_PER_RUPEES
        member.points += earned
        member.history.append((event["sale_id"], earned))
        return {"status": "ok", "earned": earned}
    if kind == "sale.refunded":
        # Not handled yet: nobody has said what a refund does to points.
        return {"status": "ignored", "reason": "refunds not handled"}
    return {"status": "ignored", "reason": f"unknown event {kind}"}
