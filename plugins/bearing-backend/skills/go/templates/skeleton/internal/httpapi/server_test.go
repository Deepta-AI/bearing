package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/prometheus/client_golang/prometheus"

	"__MODULE__/internal/health"
)

type fakeChecker struct {
	name string
	err  error
}

func (f fakeChecker) Name() string               { return f.name }
func (f fakeChecker) Ping(context.Context) error { return f.err }

func newTestHandler(checkers ...health.Checker) http.Handler {
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	return New(logger, "test", prometheus.NewRegistry(), checkers...)
}

func get(h http.Handler, path string) *httptest.ResponseRecorder {
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequestWithContext(context.Background(), http.MethodGet, path, http.NoBody))
	return rec
}

func TestHealthzIsLiveWithoutDependencies(t *testing.T) {
	rec := get(newTestHandler(fakeChecker{name: "database", err: errors.New("down")}), "/healthz")

	if rec.Code != http.StatusOK {
		t.Fatalf("status: got %d want 200", rec.Code)
	}
	if got := rec.Header().Get("Content-Type"); got != "application/json" {
		t.Fatalf("content-type: got %q", got)
	}
	if rec.Header().Get("X-Request-Id") == "" {
		t.Fatal("request id header missing")
	}
}

func TestReadyzReportsEachDependency(t *testing.T) {
	rec := get(newTestHandler(fakeChecker{name: "database"}), "/readyz")
	if rec.Code != http.StatusOK {
		t.Fatalf("ready status: got %d want 200", rec.Code)
	}
	var body struct {
		Status string            `json:"status"`
		Checks map[string]string `json:"checks"`
	}
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if body.Checks["database"] != "ok" {
		t.Fatalf("checks: got %v", body.Checks)
	}

	rec = get(newTestHandler(fakeChecker{name: "database", err: errors.New("down")}), "/readyz")
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("not ready status: got %d want 503", rec.Code)
	}
	if !strings.Contains(rec.Body.String(), `"database":"failed"`) {
		t.Fatalf("body does not name the failed check: %s", rec.Body.String())
	}
}

func TestMetricsEndpointServesPrometheusText(t *testing.T) {
	h := newTestHandler()
	get(h, "/healthz")

	rec := get(h, "/metrics")

	if rec.Code != http.StatusOK {
		t.Fatalf("status: got %d want 200", rec.Code)
	}
	if !strings.Contains(rec.Body.String(), "app_http_requests_total") {
		t.Fatalf("metrics body lacks the request counter:\n%s", rec.Body.String())
	}
}
