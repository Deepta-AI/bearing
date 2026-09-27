from billing.events import issued_event
from billing.invoices import Invoice, Line


def test_issued_event_carries_currency():
    inv = Invoice("inv_2", "cus_3", "INR", [Line("seat", 1000)])
    ev = issued_event(inv, "2026-09-03T09:00:00Z")
    assert ev["currency"] == "INR"
    assert ev["amount_minor"] == 1180
