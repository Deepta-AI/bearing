from decimal import Decimal

from app.invoices import invoice_lines


def test_invoice_total():
    lines = invoice_lines([("Team", Decimal("29")), ("Seats", Decimal("1234.5"))], "USD")
    assert lines[-1] == "Total: $1,263.50"
    assert lines[0] == "Team: $29.00"
