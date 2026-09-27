"""Application wiring: settings, database, routers, error handlers."""

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.config import Settings, get_settings
from app.customers.router import router as customers_router
from app.db import Database
from app.errors import register_exception_handlers
from app.invoices.router import router as invoices_router
from app.migrate import migrate
from app.webhooks.router import router as webhooks_router


def create_app(settings: Settings | None = None) -> FastAPI:
    """Build the app; tests pass their own Settings."""
    settings = settings or get_settings()

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        migrate(settings.database_path)
        app.state.settings = settings
        app.state.db = Database(settings.database_path)
        yield

    docs = settings.env != "prod"
    app = FastAPI(
        title="invoices-api",
        lifespan=lifespan,
        docs_url="/docs" if docs else None,
        redoc_url=None,
        openapi_url="/openapi.json" if docs else None,
    )
    register_exception_handlers(app)
    app.include_router(customers_router)
    app.include_router(invoices_router)
    app.include_router(webhooks_router)
    return app
