"""Orders service used by the app, the web shop and the ops console.

Seed data is synthetic.
"""

from dataclasses import dataclass
from typing import Protocol


class Payments(Protocol):
    def refund(self, order_id: str, amount_paise: int) -> str: ...


class Warehouse(Protocol):
    def release_stock(self, order_id: str) -> None: ...


@dataclass
class Order:
    id: str
    customer_id: str
    items: list[str]
    total_paise: int
    status: str  # placed | confirmed | packed | shipped | delivered | cancelled


class OrdersService:
    def __init__(self, payments: Payments, warehouse: Warehouse, orders: dict[str, Order] | None = None):
        self.payments = payments
        self.warehouse = warehouse
        self.orders = orders if orders is not None else seed()

    def get_order(self, order_id: str) -> Order:
        return self.orders[order_id]

    def list_orders(self, customer_id: str) -> list[Order]:
        return [o for o in self.orders.values() if o.customer_id == customer_id]

    def cancel_order(self, order_id: str, reason: str) -> Order:
        """Cancel, refund the full amount and release stock. Used by the ops console."""
        order = self.orders[order_id]
        order.status = "cancelled"
        self.payments.refund(order.id, order.total_paise)
        self.warehouse.release_stock(order.id)
        return order


def seed() -> dict[str, Order]:
    rows = [
        Order("o_5001", "c_201", ["Steel water bottle"], 79900, "placed"),
        Order("o_5002", "c_201", ["Cotton bedsheet set"], 189900, "packed"),
        Order("o_5003", "c_201", ["Desk lamp"], 129900, "cancelled"),
        Order("o_5004", "c_202", ["Pressure cooker 5L"], 249900, "confirmed"),
        Order("o_5005", "c_202", ["Yoga mat"], 99900, "shipped"),
    ]
    return {o.id: o for o in rows}
