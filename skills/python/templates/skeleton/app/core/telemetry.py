"""OpenTelemetry bootstrap.

A no-op until `OTEL_EXPORTER_OTLP_ENDPOINT` is set; then spans export over
OTLP/HTTP and W3C trace context propagates on every request. Called once by
the application factory. Nothing else in the service imports opentelemetry.
"""

import os

import structlog
from fastapi import FastAPI

log = structlog.get_logger()


def configure_tracing(app: FastAPI, service_name: str, version: str) -> bool:
    """Install the tracer provider and instrument the app. Returns whether it did."""
    endpoint = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT", "").strip()
    if not endpoint:
        return False

    from opentelemetry import trace
    from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
    from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
    from opentelemetry.sdk.resources import SERVICE_NAME, SERVICE_VERSION, Resource
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import BatchSpanProcessor

    resource = Resource.create({SERVICE_NAME: service_name, SERVICE_VERSION: version})
    provider = TracerProvider(resource=resource)
    provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
    trace.set_tracer_provider(provider)
    FastAPIInstrumentor.instrument_app(app, excluded_urls="healthz,readyz,metrics")
    log.info("tracing enabled", endpoint=endpoint)
    return True
