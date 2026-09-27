"""HTTP routes for customers."""

from typing import Annotated

from fastapi import APIRouter, Depends

from app.auth import OrgId
from app.customers.repository import CustomerRepository
from app.customers.schemas import CustomerOut
from app.customers.service import CustomerService
from app.db import Database, get_db
from app.pagination import DEFAULT_LIMIT, Cursor, Limit, Page

router = APIRouter(prefix="/customers", tags=["customers"])


def customer_service(db: Annotated[Database, Depends(get_db)]) -> CustomerService:
    return CustomerService(CustomerRepository(db))


Service = Annotated[CustomerService, Depends(customer_service)]


@router.get("", response_model=Page[CustomerOut])
async def list_customers(
    org_id: OrgId, service: Service, limit: Limit = DEFAULT_LIMIT, cursor: Cursor = None
) -> Page[CustomerOut]:
    customers, next_cursor = await service.list(org_id, limit, cursor)
    return Page[CustomerOut](items=[CustomerOut.of(c) for c in customers], next_cursor=next_cursor)


@router.get("/{customer_id}", response_model=CustomerOut)
async def get_customer(customer_id: str, org_id: OrgId, service: Service) -> CustomerOut:
    return CustomerOut.of(await service.get(org_id, customer_id))
