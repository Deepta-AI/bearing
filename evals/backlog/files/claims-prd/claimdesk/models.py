"""Users and claims."""

from dataclasses import dataclass, field
from datetime import date

ROLES = ("employee", "finance_admin")

STATUSES = ("draft", "submitted", "approved", "rejected", "paid")


@dataclass
class User:
    id: int
    name: str
    email: str
    role: str = "employee"


@dataclass
class Receipt:
    filename: str
    content_type: str
    size_bytes: int


@dataclass
class Claim:
    id: int
    owner_id: int
    spent_on: date
    amount_inr: int
    category: str
    description: str
    status: str = "draft"
    receipts: list = field(default_factory=list)
    decided_by: int | None = None
    reject_reason: str | None = None
    paid_on: date | None = None
