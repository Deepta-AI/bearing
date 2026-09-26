def credit(conn, customer_id, amount_paise):
    conn.execute(
        "INSERT INTO wallets (customer_id, balance_paise) VALUES (?, ?) "
        "ON CONFLICT(customer_id) DO UPDATE SET balance_paise = balance_paise + excluded.balance_paise",
        (customer_id, amount_paise),
    )
    conn.commit()


def debit(conn, customer_id, amount_paise):
    conn.execute(
        "UPDATE wallets SET balance_paise = balance_paise - ? WHERE customer_id = ?",
        (amount_paise, customer_id),
    )
    conn.commit()


def balance(conn, customer_id):
    row = conn.execute(
        "SELECT balance_paise FROM wallets WHERE customer_id = ?", (customer_id,)
    ).fetchone()
    return row[0] if row else 0
