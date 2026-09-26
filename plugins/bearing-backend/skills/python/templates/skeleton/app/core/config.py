"""Process configuration from the environment.

Construction fails fast and names every invalid variable at once. Secrets
have no defaults. `get_settings` is the one module-level singleton.
"""

from functools import lru_cache
from typing import Literal

from pydantic import PostgresDsn, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

Env = Literal["development", "test", "production"]
LogLevel = Literal["debug", "info", "warning", "error"]
LogFormat = Literal["json", "console"]


class Settings(BaseSettings):
    """Validated process configuration, read from the environment and .env."""

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = "__REPO_NAME__"
    env: Env = "development"
    port: int = 8080
    log_level: LogLevel = "info"
    log_format: LogFormat = "json"
    database_url: PostgresDsn
    db_pool_size: int = 5
    db_pool_max_overflow: int = 10
    db_echo: bool = False

    @field_validator("database_url")
    @classmethod
    def _async_driver(cls, value: PostgresDsn) -> PostgresDsn:
        """The whole stack is async; a sync driver here would block the loop."""
        if value.scheme != "postgresql+asyncpg":
            msg = f"DATABASE_URL must use postgresql+asyncpg://, got {value.scheme}://"
            raise ValueError(msg)
        return value


@lru_cache
def get_settings() -> Settings:
    """Load settings once per process."""
    return Settings()
