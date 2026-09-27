"""Customer response models."""

from pydantic import BaseModel

from app.customers.repository import Customer


class CustomerOut(BaseModel):
    id: str
    name: str
    email: str
    created_at: str

    @classmethod
    def of(cls, c: Customer) -> "CustomerOut":
        return cls(id=c.id, name=c.name, email=c.email, created_at=c.created_at)
