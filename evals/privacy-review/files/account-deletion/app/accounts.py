import hashlib
import logging
import os

log = logging.getLogger("mealbox.accounts")


def _hash(password, salt=None):
    salt = salt or os.urandom(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 200_000)
    return salt.hex() + ":" + digest.hex()


def _verify(password, stored):
    salt_hex, _ = stored.split(":")
    return _hash(password, bytes.fromhex(salt_hex)) == stored


def sign_up(db, email, name, password, phone=None, marketing_opt_in=False):
    cur = db.execute(
        "INSERT INTO users (email, name, phone, password_hash, marketing_opt_in)"
        " VALUES (?, ?, ?, ?, ?)",
        (email.lower(), name, phone, _hash(password), int(marketing_opt_in)),
    )
    db.commit()
    return cur.lastrowid


def log_in(db, email, password, ip, user_agent=""):
    user = db.execute(
        "SELECT * FROM users WHERE email = ? AND deleted_at IS NULL", (email.lower(),)
    ).fetchone()
    if user is None or not _verify(password, user["password_hash"]):
        log.warning("failed login for %s from %s", email, ip)
        return None
    db.execute(
        "INSERT INTO login_events (user_id, ip, user_agent) VALUES (?, ?, ?)",
        (user["id"], ip, user_agent),
    )
    db.commit()
    return user["id"]


def delete_account(db, user_id):
    """Settings page, "Delete my account"."""
    user = db.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    if user is None:
        return False
    log.info("deleting account %s", dict(user))
    db.execute("UPDATE users SET deleted_at = CURRENT_TIMESTAMP WHERE id = ?", (user_id,))
    db.commit()
    return True
