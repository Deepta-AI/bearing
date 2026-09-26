package middleware

import (
	"context"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/testutil"
)

func TestRequestIDEchoesOrMints(t *testing.T) {
	var seen string
	h := RequestID(http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
		seen = RequestIDFrom(r.Context())
	}))

	rec := httptest.NewRecorder()
	req := httptest.NewRequestWithContext(context.Background(), http.MethodGet, "/", http.NoBody)
	req.Header.Set(HeaderRequestID, "abc-123")
	h.ServeHTTP(rec, req)
	if seen != "abc-123" || rec.Header().Get(HeaderRequestID) != "abc-123" {
		t.Fatalf("echo: got ctx %q header %q", seen, rec.Header().Get(HeaderRequestID))
	}

	rec = httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequestWithContext(context.Background(), http.MethodGet, "/", http.NoBody))
	if got := rec.Header().Get(HeaderRequestID); len(got) != 32 {
		t.Fatalf("minted id: got %q", got)
	}
}

func TestRecoverWrites500(t *testing.T) {
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	called := false
	writeErr := func(w http.ResponseWriter, status int, _, _ string) { called = true; w.WriteHeader(status) }
	h := Recover(logger, writeErr)(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { panic("boom") }))

	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequestWithContext(context.Background(), http.MethodGet, "/", http.NoBody))

	if !called || rec.Code != http.StatusInternalServerError {
		t.Fatalf("got called=%v status=%d", called, rec.Code)
	}
}

func TestMetricsCountsByRouteAndStatus(t *testing.T) {
	reg := prometheus.NewRegistry()
	m := NewMetrics(reg, "test")
	mux := http.NewServeMux()
	mux.HandleFunc("GET /things/{id}", func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusNoContent) })
	h := m.Handler(mux)

	h.ServeHTTP(httptest.NewRecorder(), httptest.NewRequestWithContext(context.Background(), http.MethodGet, "/things/1", http.NoBody))
	h.ServeHTTP(httptest.NewRecorder(), httptest.NewRequestWithContext(context.Background(), http.MethodGet, "/things/2", http.NoBody))
	h.ServeHTTP(httptest.NewRecorder(), httptest.NewRequestWithContext(context.Background(), http.MethodGet, "/nowhere", http.NoBody))

	if got := testutil.ToFloat64(m.requests.WithLabelValues("GET", "GET /things/{id}", "204")); got != 2 {
		t.Fatalf("matched route count: got %v want 2", got)
	}
	if got := testutil.ToFloat64(m.requests.WithLabelValues("GET", "unmatched", "404")); got != 1 {
		t.Fatalf("unmatched count: got %v want 1", got)
	}
}
