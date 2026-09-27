import os
import tempfile
from contextlib import closing

from export.db import connect


def make_db(events, accounts=(("acc_1", "eu"), ("acc_2", "us"))):
    """Create a temp events database; events are
    (event_id, account_id, kind, created_at) tuples."""
    d = tempfile.mkdtemp()
    path = os.path.join(d, "events.db")
    with closing(connect(path)) as conn:
        conn.executemany("INSERT INTO accounts VALUES (?, ?)", accounts)
        conn.executemany(
            "INSERT INTO events (event_id, account_id, kind, created_at, hour, payload) "
            "VALUES (?, ?, ?, ?, ?, ?)",
            [(e, a, k, c, c[:13], '{"n": 1}') for e, a, k, c in events],
        )
        conn.commit()
    return path, d
