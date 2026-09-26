from payments.ledger import Ledger


def test_balance_nets_refunds():
    l = Ledger()
    l.record("o1", "capture", 5000)
    l.record("o1", "refund", 1500)
    assert l.balance("o1") == 3500


def test_export_csv_has_header_and_rows():
    l = Ledger()
    l.record("o1", "capture", 5000)
    lines = l.export_csv().splitlines()
    assert lines == ["order_id,kind,amount_paise", "o1,capture,5000"]
