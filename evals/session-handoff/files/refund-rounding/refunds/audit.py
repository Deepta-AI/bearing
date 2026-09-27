"""One log line per refund so support can trace it (PAY-140)."""
import logging

log = logging.getLogger("refunds")


def record(refund_id: str, order_id: str, amount, reason: str) -> None:
    log.info("refund %s order=%s amount=%s reason=%s", refund_id, order_id, amount, reason)
