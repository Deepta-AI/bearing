def place_order(db, user_id, total_paise):
    user = db.execute("SELECT name FROM users WHERE id = ?", (user_id,)).fetchone()
    addr = db.execute(
        "SELECT line1, city, pincode FROM addresses WHERE user_id = ? ORDER BY id DESC LIMIT 1",
        (user_id,),
    ).fetchone()
    cur = db.execute(
        "INSERT INTO orders (user_id, total_paise) VALUES (?, ?)", (user_id, total_paise)
    )
    order_id = cur.lastrowid
    address = f"{addr['line1']}, {addr['city']} {addr['pincode']}" if addr else ""
    db.execute(
        "INSERT INTO invoices (order_id, billing_name, billing_address, total_paise)"
        " VALUES (?, ?, ?, ?)",
        (order_id, user["name"], address, total_paise),
    )
    db.commit()
    return order_id


def add_address(db, user_id, line1, city, pincode):
    cur = db.execute(
        "INSERT INTO addresses (user_id, line1, city, pincode) VALUES (?, ?, ?, ?)",
        (user_id, line1, city, pincode),
    )
    db.commit()
    return cur.lastrowid
