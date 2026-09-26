"""Rules for creating, submitting and deciding claims."""

from . import config
from .models import Claim, Receipt, User

CATEGORIES = ("travel", "meals", "lodging", "equipment", "other")


class ClaimError(ValueError):
    pass


def attach_receipt(claim: Claim, receipt: Receipt) -> None:
    if receipt.content_type not in config.ALLOWED_RECEIPT_TYPES:
        raise ClaimError(f"unsupported receipt type {receipt.content_type}")
    if receipt.size_bytes > config.MAX_RECEIPT_MB * 1024 * 1024:
        raise ClaimError(f"receipt larger than {config.MAX_RECEIPT_MB} MB")
    claim.receipts.append(receipt)


def submit(claim: Claim) -> None:
    if claim.status != "draft":
        raise ClaimError("only a draft can be submitted")
    if claim.amount_inr <= 0:
        raise ClaimError("amount must be positive")
    if claim.category not in CATEGORIES:
        raise ClaimError(f"unknown category {claim.category}")
    if not claim.receipts:
        raise ClaimError("a receipt is required")
    claim.status = "submitted"
    if claim.amount_inr < config.AUTO_APPROVE_BELOW_INR:
        claim.status = "approved"


def decide(claim: Claim, approver: User, approve: bool, reason: str | None = None) -> None:
    # TODO: only the claimant's manager should decide; there is no manager
    # link on User yet, so any finance admin can decide for now.
    if approver.role != "finance_admin":
        raise ClaimError("not allowed to decide claims")
    if claim.status != "submitted":
        raise ClaimError("only a submitted claim can be decided")
    if approver.id == claim.owner_id:
        raise ClaimError("cannot decide your own claim")
    if approve:
        claim.status = "approved"
    else:
        claim.status = "rejected"
        claim.reject_reason = reason
    claim.decided_by = approver.id
