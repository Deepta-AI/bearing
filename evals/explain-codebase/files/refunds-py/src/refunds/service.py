from refunds import log
from refunds.errors import NotFound, OverRefund
from refunds.store import Store
from refunds.validation import RefundRequest

# Refunds above this need a manager (Rs 5,000, in paise).
MANAGER_APPROVAL_ABOVE = 500_000

logger = log.get("refunds.service")


def needs_approval(amount_paise: int) -> bool:
    return amount_paise > MANAGER_APPROVAL_ABOVE


class RefundService:
    def __init__(self, store: Store):
        self.store = store

    def create(self, req: RefundRequest) -> dict:
        paid = self.store.paid(req.order_id)
        if paid is None:
            raise NotFound(f"order {req.order_id} not found")
        if self.store.refunded(req.order_id) + req.amount_paise > paid:
            raise OverRefund("refund exceeds amount paid")
        status = "awaiting_approval" if needs_approval(req.amount_paise) else "approved"
        refund_id = self.store.insert_refund(req.order_id, req.amount_paise, req.reason, status)
        logger.info("refund created id=%s status=%s", refund_id, status)
        return {"id": refund_id, "status": status}
