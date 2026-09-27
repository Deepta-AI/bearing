"""Customer rules: lookups are per organisation; another org's customer does not exist."""

from app.customers.repository import Customer, CustomerRepository
from app.errors import NotFoundError
from app.pagination import decode_cursor, encode_cursor


class CustomerService:
    def __init__(self, repo: CustomerRepository) -> None:
        self.repo = repo

    async def get(self, org_id: str, customer_id: str) -> Customer:
        customer = await self.repo.get(org_id, customer_id)
        if customer is None:
            raise NotFoundError(f"customer {customer_id}")
        return customer

    async def list(
        self, org_id: str, limit: int, cursor: str | None
    ) -> tuple[list[Customer], str | None]:
        after = decode_cursor(cursor) if cursor else None
        rows = await self.repo.list_newest_first(org_id, limit + 1, after)
        page, more = rows[:limit], len(rows) > limit
        next_cursor = encode_cursor(page[-1].created_at, page[-1].id) if more else None
        return page, next_cursor
