"""Invoice rules."""

from app.errors import NotFoundError
from app.invoices.repository import Invoice, InvoiceRepository


class InvoiceService:
    def __init__(self, repo: InvoiceRepository) -> None:
        self.repo = repo

    async def get(self, org_id: str, invoice_id: str) -> Invoice:
        invoice = await self.repo.get(org_id, invoice_id)
        if invoice is None:
            raise NotFoundError(f"invoice {invoice_id}")
        return invoice
