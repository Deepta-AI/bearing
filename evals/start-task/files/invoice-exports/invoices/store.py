"""In-memory invoice store. The real deployment loads it from the ledger
export at start-up; tests build it directly."""

from datetime import date

from .models import Invoice


class InvoiceStore:
    def __init__(self, invoices=None):
        self._invoices = list(invoices or [])

    def add(self, invoice: Invoice) -> None:
        if any(i.number == invoice.number for i in self._invoices):
            raise ValueError(f"duplicate invoice number {invoice.number}")
        self._invoices.append(invoice)

    def all(self) -> list[Invoice]:
        return sorted(self._invoices, key=lambda i: (i.issued_on, i.number))

    def get(self, number: str) -> Invoice:
        for i in self._invoices:
            if i.number == number:
                return i
        raise KeyError(number)


def sample_store() -> InvoiceStore:
    return InvoiceStore(
        [
            Invoice("INV-1001", "Acme Traders", date(2026, 7, 30), 1250000),
            Invoice("INV-1002", "Blue Lotus Foods", date(2026, 8, 2), 480050),
            Invoice("INV-1003", "Acme Traders", date(2026, 8, 31), 99999),
            Invoice("INV-1004", "Kite Logistics", date(2026, 9, 1), 2000000),
        ]
    )
