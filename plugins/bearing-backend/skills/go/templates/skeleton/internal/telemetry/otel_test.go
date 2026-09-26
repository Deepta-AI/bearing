package telemetry

import (
	"context"
	"testing"
)

func TestSetupIsNoopWithoutEndpoint(t *testing.T) {
	t.Setenv("OTEL_EXPORTER_OTLP_ENDPOINT", "")

	shutdown, err := Setup(context.Background(), "test", "dev")

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if err := shutdown(context.Background()); err != nil {
		t.Fatalf("noop shutdown returned %v", err)
	}
}
