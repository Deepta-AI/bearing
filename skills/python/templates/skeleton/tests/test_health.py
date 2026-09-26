"""Health routes and the request-id contract."""

from fastapi import FastAPI
from httpx import AsyncClient

from app import __version__
from app.api.health.router import get_readiness_check


async def test_healthz_reports_version(client: AsyncClient) -> None:
    response = await client.get("/healthz")

    assert response.status_code == 200
    assert response.json() == {"status": "ok", "version": __version__}


async def test_request_id_is_echoed(client: AsyncClient) -> None:
    response = await client.get("/healthz", headers={"x-request-id": "abc-123"})

    assert response.headers["x-request-id"] == "abc-123"


async def test_request_id_is_minted_when_missing(client: AsyncClient) -> None:
    response = await client.get("/healthz")

    assert len(response.headers["x-request-id"]) == 32


async def test_readyz_ok_when_database_answers(app: FastAPI, client: AsyncClient) -> None:
    async def healthy() -> None:
        return None

    app.dependency_overrides[get_readiness_check] = lambda: healthy

    response = await client.get("/readyz")

    assert response.status_code == 200
    assert response.json() == {"status": "ok", "checks": {"database": "ok"}}


async def test_readyz_503_when_database_is_down(app: FastAPI, client: AsyncClient) -> None:
    async def down() -> None:
        raise ConnectionRefusedError("no route to postgres")

    app.dependency_overrides[get_readiness_check] = lambda: down

    response = await client.get("/readyz", headers={"x-request-id": "r-1"})

    assert response.status_code == 503
    body = response.json()
    assert body["error"]["code"] == "service_unavailable"
    assert body["error"]["details"] == {"database": "failed"}
    assert body["error"]["request_id"] == "r-1"
