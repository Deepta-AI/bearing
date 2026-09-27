"""Cart totals, coupons and shipping. Amounts are in paise."""

from dataclasses import dataclass, field
from datetime import date

FREE_SHIPPING_FROM = 500_00  # carts of 500 rupees or more ship free
SHIPPING_FEE = 40_00


@dataclass(frozen=True)
class Coupon:
    code: str
    percent: int
    expires: date  # last day the coupon can be used


@dataclass
class Cart:
    lines: list[tuple[str, int, int]] = field(default_factory=list)  # (sku, qty, unit price)
    coupon: Coupon | None = None

    def add(self, sku: str, qty: int, unit_price: int) -> None:
        self.lines.append((sku, qty, unit_price))

    @property
    def empty(self) -> bool:
        return not self.lines

    @property
    def subtotal(self) -> int:
        return sum(qty * price for _, qty, price in self.lines)

    def apply_coupon(self, coupon: Coupon, today: date | None = None) -> bool:
        """Attach the coupon if it has not expired; returns whether it applied."""
        today = today or date.today()
        if today > coupon.expires:
            return False
        self.coupon = coupon
        return True

    @property
    def discount(self) -> int:
        if self.coupon is None:
            return 0
        return self.subtotal * self.coupon.percent // 100

    @property
    def shipping(self) -> int:
        if self.empty:
            return 0
        return 0 if self.subtotal >= FREE_SHIPPING_FROM else SHIPPING_FEE

    @property
    def total(self) -> int:
        return self.subtotal - self.discount + self.shipping
