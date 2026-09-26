import pytest

from payouts.settlement import Line, settle


def test_one_payout_per_seller_in_id_order():
    lines = [
        Line("o1", "s2", 10000, 250),
        Line("o2", "s1", 20000, 250),
        Line("o3", "s2", 4000, 250),
    ]
    payouts = settle(lines)
    assert [p.seller_id for p in payouts] == ["s1", "s2"]
    assert payouts[1].gross_paise == 14000
    assert payouts[1].fee_paise == 350
    assert payouts[1].net_paise == 13650


def test_held_seller_is_left_out():
    lines = [Line("o1", "s1", 10000, 250), Line("o2", "s9", 10000, 250)]
    assert [p.seller_id for p in settle(lines, held_sellers={"s9"})] == ["s1"]


def test_negative_line_rejected():
    with pytest.raises(ValueError):
        settle([Line("o1", "s1", -5, 250)])
