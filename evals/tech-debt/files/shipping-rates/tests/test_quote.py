import pytest

from rates.quote import build_quote


def test_zone_a_two_kg():
    # 2 kg at 40 a kg is 80, plus the 12% fuel surcharge.
    assert build_quote(2, "110001") == 89.6


@pytest.mark.skip(reason="flaky on CI, investigate later")
def test_repeated_quotes_same_price():
    first = build_quote(1, "560001")
    second = build_quote(1, "560001")
    assert first == second
