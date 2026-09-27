from billing.invoices import Invoice, Line, next_invoice_id


def test_total_adds_tax_on_whole_invoice():
    inv = Invoice("inv_1", "cus_1", "INR", [Line("seat", 1000, 3), Line("setup", 499)])
    assert inv.subtotal_minor() == 3499
    assert inv.tax_minor() == 630
    assert inv.total_minor() == 4129


def test_next_invoice_id():
    assert next_invoice_id("inv_1009") == "inv_1010"
