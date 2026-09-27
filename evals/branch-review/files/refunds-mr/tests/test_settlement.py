from payments import settlement


def test_payout_counts_paid_orders_only(conn):
    assert settlement.payout_paise(conn, 1) == 100000


def test_payout_is_net_of_refunds(conn):
    conn.execute("UPDATE orders SET refunded_paise = 30000 WHERE id = 10")
    assert settlement.payout_paise(conn, 1) == 70000
