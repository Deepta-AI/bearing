from . import config


def reindex(conn, environ, body, **_):
    if environ.get("HTTP_X_ADMIN_TOKEN") != config.ADMIN_TOKEN:
        return 401, {"error": "unauthorized"}
    conn.execute("REINDEX")
    conn.execute("ANALYZE")
    return 200, {"ok": True}


ADMIN_ROUTES = [
    ("POST", r"/admin/reindex", reindex),
]
