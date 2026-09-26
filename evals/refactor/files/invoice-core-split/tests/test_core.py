import pytest

from invoicing.core import (
    Invoice,
    LineItem,
    apply_discount,
    compute_totals,
    format_money,
    parse_line,
)


def make_invoice(region="KA"):
    inv = Invoice("INV-00001", "Asha Stores", region)
    inv.add(LineItem("NB-A5", "Notebook A5", 2, 1000))
    inv.add(LineItem("PEN-01", "Gel pen", 1, 550))
    return inv


def test_line_amount():
    assert LineItem("X", "x", 3, 250).amount_paise == 750


def test_add_rejects_zero_quantity():
    inv = Invoice("INV-00001", "c", "KA")
    with pytest.raises(ValueError, match="quantity must be positive"):
        inv.add(LineItem("X", "x", 0, 100))


def test_totals_karnataka():
    assert compute_totals(make_invoice()) == {
        "subtotal": 2550,
        "tax": 459,
        "total": 3009,
    }


def test_totals_tamil_nadu():
    assert compute_totals(make_invoice("TN"))["tax"] == 306


def test_discount_line():
    inv = make_invoice()
    assert apply_discount(inv, 10) == 255
    assert inv.items[-1].amount_paise == -255


def test_discount_limit():
    with pytest.raises(ValueError):
        apply_discount(make_invoice(), 40)


def test_format_money():
    assert format_money(123456) == "Rs 1,234.56"
    assert format_money(-5) == "-Rs 0.05"


def test_parse_line():
    assert parse_line("PEN-01 | Gel pen | 3 | 2500") == LineItem("PEN-01", "Gel pen", 3, 2500)
