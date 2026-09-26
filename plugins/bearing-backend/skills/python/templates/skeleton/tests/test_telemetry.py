"""Tracing stays off without an endpoint and instruments the app with one."""

import pytest
from fastapi import FastAPI

from app.core.telemetry import configure_tracing


def test_tracing_is_noop_without_endpoint(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("OTEL_EXPORTER_OTLP_ENDPOINT", raising=False)
    app = FastAPI()

    assert configure_tracing(app, "test", "0.0.0") is False
    assert getattr(app, "_is_instrumented_by_opentelemetry", False) is False


def test_tracing_instruments_with_endpoint(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4318")
    app = FastAPI()

    assert configure_tracing(app, "test", "0.0.0") is True
    assert getattr(app, "_is_instrumented_by_opentelemetry", False) is True
