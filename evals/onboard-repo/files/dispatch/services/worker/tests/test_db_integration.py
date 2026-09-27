import socket
from urllib.parse import urlparse

import pytest

from worker.db import database_url


@pytest.mark.integration
def test_can_reach_postgres():
    # CI starts a postgres service and sets DATABASE_URL; locally this needs
    # `docker compose up db` and the variable exported.
    url = urlparse(database_url())
    assert url.scheme in ("postgres", "postgresql")
    with socket.create_connection((url.hostname, url.port or 5432), timeout=3):
        pass
