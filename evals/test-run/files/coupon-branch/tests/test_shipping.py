from shop.shipping import shipping


def test_tc_0250_free_shipping_from_500():
    assert shipping(50000) == 0


def test_tc_0251_shipping_below_threshold():
    assert shipping(10000) == 4900
