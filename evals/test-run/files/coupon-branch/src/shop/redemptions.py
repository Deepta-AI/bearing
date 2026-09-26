"""Coupon redemptions: each single-use coupon is redeemed once per customer."""


class AlreadyRedeemed(Exception):
    pass


def redeem(conn, customer_id, code):
    """Record a redemption; a second redemption of the same code raises."""
    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO redemptions (customer_id, code) VALUES (%s, %s) "
            "ON CONFLICT (customer_id, code) DO NOTHING",
            (customer_id, code),
        )
        if cur.rowcount == 0:
            raise AlreadyRedeemed(code)
