import hashlib
import hmac
import json
import sqlite3
from contextlib import closing

from fastapi.testclient import TestClient

from tests.conftest import WEBHOOK_SECRET


def refund(event_id: str, invoice_id: str, amount: int) -> dict[str, object]:
    return {
        "id": event_id,
        "type": "refund.succeeded",
        "created": "2026-09-20T10:00:00Z",
        "data": {
            "invoice_id": invoice_id,
            "amount_minor": amount,
            "currency": "INR",
            "customer_email": "accounts@asha.example",
        },
    }


def post(client: TestClient, payload: dict[str, object]) -> int:
    body = json.dumps(payload).encode()
    digest = hmac.new(WEBHOOK_SECRET.encode(), body, hashlib.sha256).hexdigest()
    r = client.post(
        "/webhooks/refunds",
        content=body,
        headers={"X-Signature": f"sha256={digest}", "Content-Type": "application/json"},
    )
    return r.status_code


def refunded(db_path: str, invoice_id: str) -> int:
    with closing(sqlite3.connect(db_path)) as conn:
        row = conn.execute(
            "SELECT amount_refunded_minor FROM invoices WHERE id = ?", (invoice_id,)
        ).fetchone()
    return int(row[0])


def test_refund_is_recorded(client: TestClient, db_path: str) -> None:
    assert post(client, refund("evt_r1", "inv_a1_1", 25000)) == 200
    assert refunded(db_path, "inv_a1_1") == 25000


def test_partial_refunds_add_up(client: TestClient, db_path: str) -> None:
    assert post(client, refund("evt_r2", "inv_a1_1", 10000)) == 200
    assert post(client, refund("evt_r3", "inv_a1_1", 5000)) == 200
    assert refunded(db_path, "inv_a1_1") == 15000
