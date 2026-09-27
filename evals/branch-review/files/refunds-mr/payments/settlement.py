def payout_paise(conn, merchant_id):
    """What the merchant is paid out at the end of the day.

    Paid orders only, less whatever has been refunded to the customer on
    each order (orders.refunded_paise), since that money has gone back
    through the card gateway and is no longer the merchant's.
    """
    row = conn.execute(
        "SELECT COALESCE(SUM(total_paise - refunded_paise), 0) FROM orders "
        "WHERE merchant_id = ? AND status = 'paid'",
        (merchant_id,),
    ).fetchone()
    return row[0]
