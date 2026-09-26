"""In-process store. Seed data is synthetic; suppliers and keys are made up."""

from dataclasses import dataclass, field


@dataclass
class Supplier:
    name: str
    contact_email: str
    contact_phone: str
    portal_api_key: str  # used by the nightly PO sync to log in to the supplier portal


@dataclass
class Sku:
    sku: str
    title: str
    category: str
    supplier: Supplier
    archived: bool = False


@dataclass
class Movement:
    sku: str
    warehouse: str
    delta: int
    reason: str
    at: str


@dataclass
class Store:
    skus: dict[str, Sku] = field(default_factory=dict)
    stock: dict[tuple[str, str], int] = field(
        default_factory=dict
    )  # (sku, warehouse) -> units
    movements: list[Movement] = field(default_factory=list)


WAREHOUSES = ("BLR-1", "PNQ-1", "DEL-2")


def seeded() -> Store:
    steel = Supplier(
        "Kavya Steelworks",
        "orders@kavya-steel.example",
        "+91 90000 00011",
        "sk-test-000-supplier-kavya",
    )
    loom = Supplier(
        "Tara Looms",
        "sales@tara-looms.example",
        "+91 90000 00022",
        "sk-test-000-supplier-tara",
    )
    s = Store()
    for sku in (
        Sku("KS-BOTTLE-750", "Steel bottle 750 ml", "kitchen", steel),
        Sku("KS-TIFFIN-3", "Three tier tiffin", "kitchen", steel),
        Sku("TL-SHEET-DBL", "Cotton bedsheet, double", "home", loom),
        Sku(
            "TL-SHEET-DBL-2", "Cotton bedsheet, double (duplicate entry)", "home", loom
        ),
        Sku("TL-TOWEL-BATH", "Bath towel", "home", loom),
    ):
        s.skus[sku.sku] = sku
    for sku, wh, qty in (
        ("KS-BOTTLE-750", "BLR-1", 420),
        ("KS-BOTTLE-750", "PNQ-1", 130),
        ("KS-TIFFIN-3", "BLR-1", 75),
        ("TL-SHEET-DBL", "DEL-2", 260),
    ):
        s.stock[(sku, wh)] = qty
        s.movements.append(
            Movement(sku, wh, qty, "opening balance", "2026-08-01T09:00:00+05:30")
        )
    s.stock[("TL-TOWEL-BATH", "PNQ-1")] = 0
    s.movements.append(
        Movement(
            "TL-TOWEL-BATH",
            "PNQ-1",
            40,
            "goods receipt GR-7781",
            "2026-08-12T11:20:00+05:30",
        )
    )
    s.movements.append(
        Movement("TL-TOWEL-BATH", "PNQ-1", -40, "sold out", "2026-09-02T18:05:00+05:30")
    )
    return s
