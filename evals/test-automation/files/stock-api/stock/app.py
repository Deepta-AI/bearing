import json
import re
import sqlite3

from . import alerts, config, db
from .admin import ADMIN_ROUTES

LOW_STOCK_THRESHOLD = 5
SKU = re.compile(r"^[A-Z0-9-]{1,32}$")


def healthz(conn, environ, body, **_):
    conn.execute("SELECT 1")
    return 200, {"status": "ok"}


def list_items(conn, environ, body, **_):
    rows = conn.execute("SELECT sku, name, qty FROM items ORDER BY sku").fetchall()
    return 200, [dict(r) for r in rows]


def get_item(conn, environ, body, sku):
    row = conn.execute("SELECT sku, name, qty FROM items WHERE sku = ?", (sku,)).fetchone()
    if row is None:
        return 404, {"error": "not_found"}
    return 200, dict(row)


def create_item(conn, environ, body, **_):
    if not isinstance(body, dict):
        return 400, {"error": "bad_body"}
    sku, name, qty = body.get("sku"), body.get("name"), body.get("qty")
    if not isinstance(sku, str) or not SKU.match(sku):
        return 400, {"error": "bad_sku"}
    if not isinstance(name, str) or not name.strip():
        return 400, {"error": "bad_name"}
    if not isinstance(qty, int) or isinstance(qty, bool) or qty < 0:
        return 400, {"error": "bad_qty"}
    try:
        conn.execute("INSERT INTO items (sku, name, qty) VALUES (?, ?, ?)", (sku, name, qty))
        conn.commit()
    except sqlite3.IntegrityError:
        return 409, {"error": "duplicate_sku"}
    return 201, {"sku": sku, "name": name, "qty": qty}


def adjust(conn, environ, body, sku):
    if not isinstance(body, dict) or not isinstance(body.get("delta"), int):
        return 400, {"error": "bad_body"}
    row = conn.execute("SELECT qty FROM items WHERE sku = ?", (sku,)).fetchone()
    if row is None:
        return 404, {"error": "not_found"}
    new_qty = row["qty"] + body["delta"]
    if new_qty < 0:
        return 409, {"error": "insufficient_stock"}
    conn.execute("UPDATE items SET qty = ? WHERE sku = ?", (new_qty, sku))
    conn.commit()
    if new_qty < LOW_STOCK_THRESHOLD:
        alerts.send_low_stock(sku, new_qty)
    return get_item(conn, environ, body, sku=sku)


ROUTES = [
    ("GET", r"/healthz", healthz),
    ("GET", r"/items", list_items),
    ("POST", r"/items", create_item),
    ("GET", r"/items/(?P<sku>[A-Z0-9-]+)", get_item),
    ("POST", r"/items/(?P<sku>[A-Z0-9-]+)/adjust", adjust),
] + ADMIN_ROUTES

REASONS = {200: "OK", 201: "Created", 400: "Bad Request", 401: "Unauthorized",
           404: "Not Found", 405: "Method Not Allowed", 409: "Conflict",
           500: "Internal Server Error"}


def make_app(db_path=None):
    conn = db.connect(db_path or config.DB_PATH)
    compiled = [(m, re.compile(p + r"$"), h) for m, p, h in ROUTES]

    def app(environ, start_response):
        method = environ["REQUEST_METHOD"]
        path = environ.get("PATH_INFO", "/")
        status, payload = 404, {"error": "not_found"}
        matched_path = False
        for m, pattern, handler in compiled:
            match = pattern.match(path)
            if not match:
                continue
            matched_path = True
            if m != method:
                continue
            try:
                length = int(environ.get("CONTENT_LENGTH") or 0)
                raw = environ["wsgi.input"].read(length) if length else b""
                body = json.loads(raw) if raw else None
            except (ValueError, json.JSONDecodeError):
                status, payload = 400, {"error": "bad_json"}
                break
            try:
                status, payload = handler(conn, environ, body, **match.groupdict())
            except Exception:
                status, payload = 500, {"error": "internal"}
            break
        else:
            if matched_path:
                status, payload = 405, {"error": "method_not_allowed"}
        data = json.dumps(payload).encode()
        start_response(
            f"{status} {REASONS.get(status, '')}",
            [("Content-Type", "application/json"), ("Content-Length", str(len(data)))],
        )
        return [data]

    return app
