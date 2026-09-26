import json

from refunds import validation
from refunds.errors import RefundError
from refunds.service import RefundService

APPROVAL_NOTE = "Refunds above Rs 5,000 need a manager's approval before they are sent."


def create_refund(service: RefundService, raw_body: bytes) -> tuple[int, dict]:
    try:
        req = validation.parse(json.loads(raw_body or b"{}"))
    except (ValueError, json.JSONDecodeError) as e:
        return 400, {"error": str(e)}
    try:
        result = service.create(req)
    except RefundError as e:
        return e.status, {"error": str(e)}
    if result["status"] == "awaiting_approval":
        result["note"] = APPROVAL_NOTE
    result["flags"] = req.flags
    return 201, result
