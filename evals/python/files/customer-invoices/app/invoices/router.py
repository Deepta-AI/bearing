"""HTTP routes for invoices."""

from typing import Annotated

from fastapi import APIRouter, Depends

from app.auth import OrgId
from app.db import Database, get_db
from app.invoices.repository import InvoiceRepository
from app.invoices.schemas import InvoiceOut
from app.invoices.service import InvoiceService

router = APIRouter(prefix="/invoices", tags=["invoices"])


def invoice_service(db: Annotated[Database, Depends(get_db)]) -> InvoiceService:
    return InvoiceService(InvoiceRepository(db))


Service = Annotated[InvoiceService, Depends(invoice_service)]


@router.get("/{invoice_id}", response_model=InvoiceOut)
async def get_invoice(invoice_id: str, org_id: OrgId, service: Service) -> InvoiceOut:
    return InvoiceOut.of(await service.get(org_id, invoice_id))
