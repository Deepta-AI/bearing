from billing.invoices import next_invoice_id


def test_next_id_after_a_round_number():
    assert next_invoice_id("inv_1999") == "inv_2000"


def test_next_id_keeps_the_width():
    # Ledger ids are fixed width: the ledger team sorts them as strings.
    assert next_invoice_id("inv_0099") == "inv_0100"
