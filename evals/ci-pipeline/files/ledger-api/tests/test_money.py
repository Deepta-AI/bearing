import pytest

from ledger.money import format_amount, parse_amount


@pytest.mark.parametrize(
    ("text", "paise"),
    [("0", 0), ("12", 1200), ("12.5", 1250), ("12.05", 1205), ("-3.10", -310)],
)
def test_parse(text, paise):
    assert parse_amount(text) == paise


@pytest.mark.parametrize("text", ["", "1.234", "abc", "1.2.3", "1,000"])
def test_parse_rejects(text):
    with pytest.raises(ValueError):
        parse_amount(text)


def test_format_round_trip():
    for value in (0, 5, 1205, -310, 123456789):
        assert parse_amount(format_amount(value)) == value
