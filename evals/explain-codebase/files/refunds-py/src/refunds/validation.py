from dataclasses import dataclass, field

from refunds.money import rupees

# Large refunds are flagged in the API response.
MANAGER_FLAG_FROM = rupees(5_000)


@dataclass
class RefundRequest:
    order_id: str
    amount_paise: int
    reason: str
    flags: list[str] = field(default_factory=list)


def parse(body: dict) -> RefundRequest:
    req = RefundRequest(
        order_id=str(body.get("order_id", "")),
        amount_paise=int(body.get("amount_paise", 0)),
        reason=str(body.get("reason", "")).strip(),
    )
    if not req.order_id:
        raise ValueError("order_id is required")
    if req.amount_paise <= 0:
        raise ValueError("amount_paise must be positive")
    if req.amount_paise >= MANAGER_FLAG_FROM:
        req.flags.append("needs_manager")
    return req
