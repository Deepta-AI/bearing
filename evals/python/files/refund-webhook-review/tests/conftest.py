"""A fresh migrated database per test, seeded with two organisations."""

import sqlite3
from collections.abc import Iterator
from contextlib import closing
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.auth import hash_key
from app.config import Settings
from app.main import create_app
from app.migrate import migrate

WEBHOOK_SECRET = "whsec_test"
KEY_A = "key-org-a"
KEY_B = "key-org-b"

CUSTOMERS = [
    ("cus_a1", "org_a", "Asha Traders", "accounts@asha.example", "2026-01-10T09:00:00Z"),
    ("cus_a2", "org_a", "Blue Kettle Cafe", "owner@bluekettle.example", "2026-02-03T12:30:00Z"),
    ("cus_a3", "org_a", "Corner Hardware", "billing@corner.example", "2026-02-03T12:30:00Z"),
    ("cus_b1", "org_b", "Delta Logistics", "ap@delta.example", "2026-01-15T08:00:00Z"),
]

# (id, org, customer, number, status, currency, amount, paid, issued_at, created_at)
INVOICES = [
    ("inv_a1_1", "org_a", "cus_a1", "INV-0001", "paid", "INR", 125000, 125000,
     "2026-06-01T10:00:00Z", "2026-05-30T10:00:00Z"),
    ("inv_a1_2", "org_a", "cus_a1", "INV-0002", "open", "INR", 48000, 0,
     "2026-07-01T09:00:00Z", "2026-06-28T10:00:00Z"),
    ("inv_a1_3", "org_a", "cus_a1", "INV-0003", "void", "INR", 9900, 0,
     "2026-07-01T09:00:00Z", "2026-06-29T10:00:00Z"),
    ("inv_a1_4", "org_a", "cus_a1", "INV-0004", "open", "INR", 30000, 10000,
     "2026-08-15T11:00:00Z", "2026-08-14T10:00:00Z"),
    ("inv_a1_5", "org_a", "cus_a1", "INV-0005", "draft", "INR", 999999, 0,
     None, "2026-09-20T10:00:00Z"),
    ("inv_a2_1", "org_a", "cus_a2", "INV-0006", "open", "INR", 15000, 0,
     "2026-09-02T10:00:00Z", "2026-09-01T10:00:00Z"),
    ("inv_b1_1", "org_b", "cus_b1", "INV-0001", "open", "INR", 70000, 0,
     "2026-07-10T10:00:00Z", "2026-07-09T10:00:00Z"),
]


def seed(path: str) -> None:
    migrate(path)
    with closing(sqlite3.connect(path)) as conn:
        conn.executemany(
            "INSERT INTO orgs (id, name) VALUES (?, ?)",
            [("org_a", "Org A"), ("org_b", "Org B")],
        )
        conn.executemany(
            "INSERT INTO api_keys (key_hash, org_id) VALUES (?, ?)",
            [(hash_key(KEY_A), "org_a"), (hash_key(KEY_B), "org_b")],
        )
        conn.executemany("INSERT INTO customers VALUES (?, ?, ?, ?, ?)", CUSTOMERS)
        conn.executemany(
            """INSERT INTO invoices (id, org_id, customer_id, number, status, currency,
               amount_minor, amount_paid_minor, issued_at, created_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            INVOICES,
        )
        conn.commit()


@pytest.fixture
def db_path(tmp_path: Path) -> str:
    path = str(tmp_path / "test.db")
    seed(path)
    return path


@pytest.fixture
def client(db_path: str) -> Iterator[TestClient]:
    settings = Settings(
        _env_file=None,  # type: ignore[call-arg]  # pydantic-settings init option
        env="test",
        database_path=db_path,
        webhook_secret=WEBHOOK_SECRET,
        accounts_notify_url="http://127.0.0.1:9/refund-notices",
    )
    with TestClient(create_app(settings)) as c:
        yield c


def auth(key: str = KEY_A) -> dict[str, str]:
    return {"Authorization": f"Bearer {key}"}
