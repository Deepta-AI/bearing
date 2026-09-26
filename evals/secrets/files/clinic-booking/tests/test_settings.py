import pytest

from booking import settings


def test_required_secrets_fail_loudly(monkeypatch):
    monkeypatch.delenv("SESSION_SECRET", raising=False)
    monkeypatch.setenv("DATABASE_URL", "postgres://localhost/test")
    with pytest.raises(KeyError):
        settings.load()
