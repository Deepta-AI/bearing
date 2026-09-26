// Package telemetry bootstraps OpenTelemetry tracing. With no collector
// endpoint configured it installs nothing, so local runs and tests pay no
// cost; with OTEL_EXPORTER_OTLP_ENDPOINT set it exports spans over OTLP/HTTP
// and propagates W3C trace context on every outgoing request.
package telemetry

import (
	"context"
	"fmt"
	"os"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
)

// Shutdown flushes and stops the tracer provider. The no-op variant returns nil.
type Shutdown func(context.Context) error

// Setup installs the global tracer provider and propagator. It reads
// OTEL_EXPORTER_OTLP_ENDPOINT (and the other OTEL_* variables the exporter
// honours) from the environment; when the endpoint is empty it returns a
// no-op shutdown and changes nothing.
func Setup(ctx context.Context, service, version string) (Shutdown, error) {
	if os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT") == "" {
		return func(context.Context) error { return nil }, nil
	}
	exp, err := otlptracehttp.New(ctx)
	if err != nil {
		return nil, fmt.Errorf("otlp exporter: %w", err)
	}
	res, err := resource.Merge(resource.Default(), resource.NewWithAttributes(
		semconv.SchemaURL,
		semconv.ServiceName(service),
		semconv.ServiceVersion(version),
	))
	if err != nil {
		return nil, fmt.Errorf("otel resource: %w", err)
	}
	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exp),
		sdktrace.WithResource(res),
	)
	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{}, propagation.Baggage{},
	))
	return tp.Shutdown, nil
}
