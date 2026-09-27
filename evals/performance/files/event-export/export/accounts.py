import functools
from contextlib import closing

from export.db import connect


@functools.lru_cache(maxsize=None)
def account_region(db_path, account_id):
    """Region of an account; accounts never change region."""
    with closing(connect(db_path)) as conn:
        row = conn.execute(
            "SELECT region FROM accounts WHERE account_id = ?", (account_id,)
        ).fetchone()
    return row[0] if row else "unknown"
