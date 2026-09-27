"""Invoice response models. Money is integer minor units plus the currency."""

from typing import Literal

from pydantic import BaseModel

from app.invoices.repository import Invoice

PublicStatus = Literal["open", "paid", "void"]


class InvoiceOut(BaseModel):
    id: str
    customer_id: str
    number: str
    status: PublicStatus
    currency: str
    amount_minor: int
    amount_paid_minor: int
    amount_refunded_minor: int
    issued_at: str

    @classmethod
    def of(cls, i: Invoice) -> "InvoiceOut":
        return cls(
            id=i.id,
            customer_id=i.customer_id,
            number=i.number,
            status=i.status,  # type: ignore[arg-type]  # drafts are filtered in the repository
            currency=i.currency,
            amount_minor=i.amount_minor,
            amount_paid_minor=i.amount_paid_minor,
            amount_refunded_minor=i.amount_refunded_minor,
            issued_at=i.issued_at,
        )
