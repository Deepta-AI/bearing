from fastapi.testclient import TestClient

from tests.conftest import KEY_B, auth


def test_get_invoice_in_minor_units(client: TestClient) -> None:
    r = client.get("/invoices/inv_a1_4", headers=auth())
    assert r.status_code == 200
    body = r.json()
    assert body["amount_minor"] == 30000
    assert body["amount_paid_minor"] == 10000
    assert body["currency"] == "INR"


def test_draft_is_not_found(client: TestClient) -> None:
    assert client.get("/invoices/inv_a1_5", headers=auth()).status_code == 404


def test_other_orgs_invoice_is_not_found(client: TestClient) -> None:
    assert client.get("/invoices/inv_a1_1", headers=auth(KEY_B)).status_code == 404
