"""Service settings, read from INVOICES_* environment variables."""

from functools import lru_cache
from typing import Literal

from fastapi import Request
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Typed settings; construction fails when a required variable is missing."""

    model_config = SettingsConfigDict(env_prefix="INVOICES_", env_file=".env", extra="ignore")

    env: Literal["dev", "test", "prod"] = "dev"
    database_path: str = "invoices.db"
    # Empty in local dev and tests; set INVOICES_WEBHOOK_SECRET in every deployed env.
    webhook_secret: str = ""
    accounts_notify_url: str = "http://accounts.internal/refund-notices"


@lru_cache
def get_settings() -> Settings:
    """The process settings, built once."""
    return Settings()  # type: ignore[call-arg]  # values come from the environment


def settings_dep(request: Request) -> Settings:
    """The settings the running app was created with."""
    settings: Settings = request.app.state.settings
    return settings
