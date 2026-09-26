ORDERS_TABLE = "orders"


def get_order(conn, order_id):
    return conn.execute(
        f"SELECT id, merchant_id, total_paise, status FROM {ORDERS_TABLE} WHERE id = ?",
        (order_id,),
    ).fetchone()
