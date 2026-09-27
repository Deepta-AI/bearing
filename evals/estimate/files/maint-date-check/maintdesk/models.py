from dataclasses import dataclass, field
from typing import Optional

STATUSES = ("open", "assigned", "closed")


@dataclass
class Vendor:
    id: int
    name: str
    trade: str
    phone: str


@dataclass
class RepairRequest:
    id: int
    flat_id: int
    tenant_phone: str
    description: str
    status: str = "open"
    vendor_id: Optional[int] = None
    rating: Optional[int] = None
    history: list = field(default_factory=list)


class Store:
    """In-memory stand-in for the Postgres repository layer."""

    def __init__(self):
        self.requests = {}
        self.vendors = {}
        self._next = 1

    def add_request(self, flat_id, tenant_phone, description):
        r = RepairRequest(self._next, flat_id, tenant_phone, description)
        r.history.append("open")
        self.requests[r.id] = r
        self._next += 1
        return r

    def add_vendor(self, vendor):
        self.vendors[vendor.id] = vendor
        return vendor
