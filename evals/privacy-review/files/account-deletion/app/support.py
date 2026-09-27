def open_ticket(db, contact_email, body, user_id=None):
    cur = db.execute(
        "INSERT INTO support_tickets (user_id, contact_email, body) VALUES (?, ?, ?)",
        (user_id, contact_email, body),
    )
    db.commit()
    return cur.lastrowid
