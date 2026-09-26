from dataclasses import dataclass, field


@dataclass
class PayablesQueue:
    """Invoices here are paid on their due date by the payment run."""

    accepted: list[dict] = field(default_factory=list)
    review: list[dict] = field(default_factory=list)

    def accept(self, invoice: dict) -> None:
        self.accepted.append(invoice)

    def send_to_review(self, invoice: dict, reason: str) -> None:
        self.review.append({"invoice": invoice, "reason": reason})
