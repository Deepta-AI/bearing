from app.invoices import Line, invoice_total, line_total, payment_status


def test_line_total_adds_gst_rounded_half_up():
    assert line_total(Line("seat", 1, 1_000)) == 1_180
    assert line_total(Line("odd", 1, 25)) == 30  # 25 + 4.5 rounds to 5


def test_invoice_total_sums_lines():
    lines = [Line("a", 2, 1_000), Line("b", 1, 500)]
    assert invoice_total(lines) == 2_360 + 590


def test_payment_status():
    assert payment_status(0, 100) == "unpaid"
    assert payment_status(40, 100) == "partial"
    assert payment_status(100, 100) == "paid"
