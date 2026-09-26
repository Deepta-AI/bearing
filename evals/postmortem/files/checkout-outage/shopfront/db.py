"""A fixed-size connection pool over sqlite3."""

import queue
import sqlite3

from shopfront import settings


class PoolTimeout(Exception):
    """No connection became free within the pool timeout."""


class Pool:
    def __init__(self, size=None, timeout=None, path=None):
        self.size = size if size is not None else settings.DB_POOL_SIZE
        self.timeout = timeout if timeout is not None else settings.DB_POOL_TIMEOUT_S
        self._free = queue.Queue()
        for _ in range(self.size):
            conn = sqlite3.connect(path or settings.DATABASE_PATH, check_same_thread=False)
            self._free.put(conn)

    def acquire(self):
        try:
            return self._free.get(timeout=self.timeout)
        except queue.Empty:
            raise PoolTimeout(f"no connection within {self.timeout}s") from None

    def release(self, conn):
        self._free.put(conn)
