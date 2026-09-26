"""Payments and refunds. Amounts are rupees; refunds are negative."""


def record_payment(conn, customer_id, amount, method="card"):
    cur = conn.execute(
        "INSERT INTO payments (customer_id, amount, method) VALUES (?, ?, ?)",
        (customer_id, amount, method),
    )
    return cur.lastrowid


def record_refund(conn, customer_id, amount, method="card"):
    return record_payment(conn, customer_id, -abs(amount), method)


def correct_amount(conn, payment_id, amount):
    """Support staff fix a mistyped amount; about 300 corrections a day."""
    conn.execute("UPDATE payments SET amount = ? WHERE id = ?", (amount, payment_id))


def total_for_customer(conn, customer_id):
    row = conn.execute(
        "SELECT COALESCE(SUM(amount), 0) FROM payments"
        " WHERE customer_id = ? AND deleted_at IS NULL AND amount IS NOT NULL",
        (customer_id,),
    ).fetchone()
    return row[0]
