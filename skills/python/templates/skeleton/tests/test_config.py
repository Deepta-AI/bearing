"""Settings fail fast and name the problem."""

import pytest
from pydantic import ValidationError

from app.core.config import Settings

DB = "postgresql+asyncpg://postgres:postgres@localhost:5432/test"


def test_defaults() -> None:
    settings = Settings(_env_file=None, database_url=DB)

    assert settings.env == "development"
    assert settings.port == 8080
    assert settings.log_level == "info"
    assert settings.log_format == "json"


def test_environment_overrides(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("LOG_LEVEL", "debug")
    monkeypatch.setenv("PORT", "9000")

    settings = Settings(_env_file=None, database_url=DB)

    assert settings.log_level == "debug"
    assert settings.port == 9000


@pytest.mark.parametrize(
    ("variable", "value"),
    [
        ("LOG_LEVEL", "loud"),
        ("ENV", "staging"),
        ("PORT", "eighty"),
    ],
)
def test_invalid_values_are_rejected(
    monkeypatch: pytest.MonkeyPatch, variable: str, value: str
) -> None:
    monkeypatch.setenv(variable, value)

    with pytest.raises(ValidationError, match=variable.lower()):
        Settings(_env_file=None, database_url=DB)


def test_sync_driver_is_rejected() -> None:
    with pytest.raises(ValidationError, match="postgresql\\+asyncpg"):
        Settings(_env_file=None, database_url="postgresql://postgres:postgres@localhost/test")
