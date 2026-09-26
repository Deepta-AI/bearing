"""Apply goose SQL migrations to SQLite with the standard library.

Understands `-- +goose Up`, `-- +goose Down` and
`-- +goose StatementBegin` / `-- +goose StatementEnd`. Records applied
versions in goose_db_version like goose does.
"""

import os
import re

MIGRATIONS = os.path.join(os.path.dirname(os.path.dirname(__file__)), "db", "migrations")
_NAME = re.compile(r"^(\d+)_[a-z0-9_]+\.sql$")


def migrations():
    out = []
    for name in sorted(os.listdir(MIGRATIONS)):
        m = _NAME.match(name)
        if m:
            out.append((int(m.group(1)), os.path.join(MIGRATIONS, name)))
    return out


def _sections(path):
    up, down, cur = [], [], None
    with open(path, encoding="utf-8") as f:
        for line in f:
            s = line.strip()
            if s == "-- +goose Up":
                cur = up
            elif s == "-- +goose Down":
                cur = down
            elif cur is not None:
                cur.append(line)
    return _statements(up), _statements(down)


def _statements(lines):
    stmts, buf, block = [], [], False
    for line in lines:
        s = line.strip()
        if s == "-- +goose StatementBegin":
            block = True
            continue
        if s == "-- +goose StatementEnd":
            block = False
            stmts.append("".join(buf))
            buf = []
            continue
        if s.startswith("--") and not buf:
            continue
        buf.append(line)
        if not block and s.endswith(";"):
            stmts.append("".join(buf))
            buf = []
    if "".join(buf).strip():
        stmts.append("".join(buf))
    return [x for x in stmts if x.strip()]


def _ensure_table(conn):
    conn.execute(
        "CREATE TABLE IF NOT EXISTS goose_db_version ("
        " id INTEGER PRIMARY KEY, version_id INTEGER NOT NULL, is_applied INTEGER NOT NULL)"
    )


def current(conn):
    _ensure_table(conn)
    row = conn.execute("SELECT MAX(version_id) FROM goose_db_version WHERE is_applied = 1").fetchone()
    return row[0] or 0


def up_to(conn, target=None):
    """Apply every migration above the current version, up to target."""
    _ensure_table(conn)
    have = current(conn)
    for version, path in migrations():
        if version <= have or (target is not None and version > target):
            continue
        up, _ = _sections(path)
        conn.execute("BEGIN")
        for stmt in up:
            conn.execute(stmt)
        conn.execute("INSERT INTO goose_db_version (version_id, is_applied) VALUES (?, 1)", (version,))
        conn.execute("COMMIT")


def down_to(conn, target):
    """Run Downs, newest first, until the current version is target."""
    _ensure_table(conn)
    for version, path in reversed(migrations()):
        if version <= target or version > current(conn):
            continue
        _, down = _sections(path)
        conn.execute("BEGIN")
        for stmt in down:
            conn.execute(stmt)
        conn.execute("DELETE FROM goose_db_version WHERE version_id = ?", (version,))
        conn.execute("COMMIT")


def schema(conn):
    """The schema as sorted lines, for comparing before and after."""
    rows = conn.execute(
        "SELECT type, name, sql FROM sqlite_master"
        " WHERE name NOT LIKE 'sqlite_%' AND name != 'goose_db_version' ORDER BY type, name"
    ).fetchall()
    return [f"{t} {n}: {' '.join((s or '').split())}" for t, n, s in rows]
