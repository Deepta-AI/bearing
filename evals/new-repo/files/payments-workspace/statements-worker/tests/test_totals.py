from statements.totals import to_paise, total_paise


def test_to_paise():
    assert to_paise("1250.50") == 125050


def test_total():
    assert total_paise(["0.10", "0.20"]) == 30
