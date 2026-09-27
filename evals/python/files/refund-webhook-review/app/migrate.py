"""Apply migrations/NNNN_name.sql in filename order, each file once."""

import sqlite3
from contextlib import closing
from pathlib import Path

MIGRATIONS = Path(__file__).resolve().parent.parent / "migrations"


def migrate(path: str) -> list[str]:
    """Apply every migration not yet recorded; return the filenames applied."""
    applied: list[str] = []
    with closing(sqlite3.connect(path)) as conn:
        conn.execute(
            "CREATE TABLE IF NOT EXISTS schema_migrations (filename TEXT PRIMARY KEY)"
        )
        done = {row[0] for row in conn.execute("SELECT filename FROM schema_migrations")}
        for file in sorted(MIGRATIONS.glob("*.sql")):
            if file.name in done:
                continue
            conn.executescript(file.read_text())
            conn.execute("INSERT INTO schema_migrations (filename) VALUES (?)", (file.name,))
            conn.commit()
            applied.append(file.name)
    return applied
