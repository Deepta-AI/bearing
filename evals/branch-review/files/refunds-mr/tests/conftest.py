import pytest

from payments import db
from payments.auth import Principal


@pytest.fixture
def conn():
    c = db.connect()
    c.executemany("INSERT INTO merchants (id, name) VALUES (?, ?)", [(1, "Acme"), (2, "Globex")])
    c.executemany(
        "INSERT INTO orders (id, merchant_id, total_paise, status) VALUES (?, ?, ?, ?)",
        [(10, 1, 100000, "paid"), (20, 2, 50000, "paid"), (30, 1, 40000, "pending")],
    )
    c.commit()
    return c


@pytest.fixture
def support():
    return Principal(user_id=7, merchant_id=1, role="support")


@pytest.fixture
def viewer():
    return Principal(user_id=8, merchant_id=1, role="viewer")
