from fastapi.testclient import TestClient

from tests.conftest import KEY_B, auth


def test_requires_an_api_key(client: TestClient) -> None:
    assert client.get("/customers").status_code == 401


def test_get_customer(client: TestClient) -> None:
    r = client.get("/customers/cus_a1", headers=auth())
    assert r.status_code == 200
    assert r.json()["name"] == "Asha Traders"


def test_other_orgs_customer_is_not_found(client: TestClient) -> None:
    r = client.get("/customers/cus_a1", headers=auth(KEY_B))
    assert r.status_code == 404
    assert r.json()["error"]["code"] == "not_found"


def test_list_pages_newest_first_across_a_tie(client: TestClient) -> None:
    first = client.get("/customers", params={"limit": 1}, headers=auth()).json()
    second = client.get(
        "/customers", params={"limit": 5, "cursor": first["next_cursor"]}, headers=auth()
    ).json()
    ids = [c["id"] for c in first["items"] + second["items"]]
    assert ids == ["cus_a3", "cus_a2", "cus_a1"]
    assert second["next_cursor"] is None


def test_limit_is_bounded(client: TestClient) -> None:
    r = client.get("/customers", params={"limit": 101}, headers=auth())
    assert r.status_code == 422
    assert r.json()["error"]["code"] == "validation_failed"


def test_bad_cursor_is_a_422(client: TestClient) -> None:
    r = client.get("/customers", params={"cursor": "not-a-cursor"}, headers=auth())
    assert r.status_code == 422
