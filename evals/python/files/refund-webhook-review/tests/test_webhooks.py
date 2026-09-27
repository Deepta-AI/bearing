import hashlib
import hmac
import json
import sqlite3
from contextlib import closing

from fastapi.testclient import TestClient

from tests.conftest import WEBHOOK_SECRET


def signed(body: bytes, secret: str = WEBHOOK_SECRET) -> dict[str, str]:
    digest = hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()
    return {"X-Signature": f"sha256={digest}", "Content-Type": "application/json"}


def payment(event_id: str, invoice_id: str, amount: int) -> bytes:
    # The provider's own spacing: verification must use these exact bytes.
    return json.dumps(
        {
            "id": event_id,
            "type": "payment.succeeded",
            "created": "2026-09-01T10:00:00Z",
            "data": {
                "invoice_id": invoice_id,
                "amount_minor": amount,
                "currency": "INR",
                "customer_email": "owner@bluekettle.example",
            },
        },
        indent=1,
    ).encode()


def paid(db_path: str, invoice_id: str) -> tuple[int, str]:
    with closing(sqlite3.connect(db_path)) as conn:
        row = conn.execute(
            "SELECT amount_paid_minor, status FROM invoices WHERE id = ?", (invoice_id,)
        ).fetchone()
    return row[0], row[1]


def test_payment_marks_invoice_paid(client: TestClient, db_path: str) -> None:
    body = payment("evt_1", "inv_a2_1", 15000)
    r = client.post("/webhooks/payments", content=body, headers=signed(body))
    assert r.status_code == 200
    assert r.json() == {"status": "applied"}
    assert paid(db_path, "inv_a2_1") == (15000, "paid")


def test_redelivered_event_is_applied_once(client: TestClient, db_path: str) -> None:
    body = payment("evt_2", "inv_a1_4", 5000)
    for _ in range(2):
        r = client.post("/webhooks/payments", content=body, headers=signed(body))
        assert r.status_code == 200
    assert paid(db_path, "inv_a1_4") == (15000, "open")


def test_bad_signature_is_rejected(client: TestClient, db_path: str) -> None:
    body = payment("evt_3", "inv_a2_1", 15000)
    r = client.post("/webhooks/payments", content=body, headers=signed(body, "wrong"))
    assert r.status_code == 401
    assert paid(db_path, "inv_a2_1") == (0, "open")


def test_other_event_types_are_ignored(client: TestClient) -> None:
    body = json.dumps(
        {"id": "evt_4", "type": "customer.updated", "created": "2026-09-01T10:00:00Z",
         "data": {"invoice_id": "inv_a2_1", "amount_minor": 1, "currency": "INR"}}
    ).encode()
    r = client.post("/webhooks/payments", content=body, headers=signed(body))
    assert r.json() == {"status": "ignored"}
