from payments import api


def test_get_own_order(conn, support):
    status, body = api.get_order(conn, support, 10)
    assert status == 200
    assert body["total_paise"] == 100000


def test_other_merchants_order_is_not_found(conn, support):
    status, _ = api.get_order(conn, support, 20)
    assert status == 404
