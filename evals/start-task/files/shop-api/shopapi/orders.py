"""Orders. Money is integer paise; the API returns paise, never rupees."""

from dataclasses import dataclass, field


@dataclass
class Line:
    sku: str
    quantity: int
    unit_paise: int


@dataclass
class Order:
    order_id: str
    lines: list[Line] = field(default_factory=list)

    def total_paise(self) -> int:
        return sum(l.quantity * l.unit_paise for l in self.lines)

    def to_json(self) -> dict:
        return {
            "order_id": self.order_id,
            "lines": [vars(l) for l in self.lines],
            "total_paise": self.total_paise(),
        }
