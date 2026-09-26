"""Place an order from a cart."""

from shopfront.db import PoolTimeout

SCHEMA = """
CREATE TABLE IF NOT EXISTS orders (
    id INTEGER PRIMARY KEY,
    customer_id TEXT NOT NULL,
    total_paise INTEGER NOT NULL,
    gift_card TEXT
)
"""


def place_order(pool, customer_id, items, gift_card=None):
    """Return (status, body). items is a list of (sku, qty, unit_paise)."""
    if not items:
        return 400, {"error": "empty cart"}
    total = sum(qty * unit for _, qty, unit in items)
    try:
        conn = pool.acquire()
    except PoolTimeout as e:
        return 500, {"error": "checkout unavailable", "detail": str(e)}
    try:
        conn.execute(SCHEMA)
        cur = conn.execute(
            "INSERT INTO orders (customer_id, total_paise, gift_card) VALUES (?, ?, ?)",
            (customer_id, total, gift_card),
        )
        conn.commit()
        return 201, {"order_id": cur.lastrowid, "total_paise": total}
    finally:
        pool.release(conn)
