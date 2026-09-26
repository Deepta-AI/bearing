// Package httpapi owns routing, the middleware chain and the JSON response
// helpers. Handlers parse and validate, call a service, and write a response.
package httpapi

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"

	"__MODULE__/internal/health"
	"__MODULE__/internal/middleware"
)

// New builds the HTTP handler. The chain, outermost first: request id, panic
// recovery, request metrics, request log, tracing, then the mux. reg is the
// Prometheus registry /metrics serves; checkers are what /readyz pings.
func New(logger *slog.Logger, version string, reg *prometheus.Registry, checkers ...health.Checker) http.Handler {
	mux := http.NewServeMux()
	h := health.New(version, checkers...)
	mux.HandleFunc("GET /healthz", h.Live)
	mux.HandleFunc("GET /readyz", h.Ready)
	mux.Handle("GET /metrics", promhttp.HandlerFor(reg, promhttp.HandlerOpts{}))

	metrics := middleware.NewMetrics(reg, "app")
	handler := otelhttp.NewHandler(mux, "http.server")
	handler = requestLog(logger, handler)
	handler = metrics.Handler(handler)
	handler = middleware.Recover(logger, WriteError)(handler)
	return middleware.RequestID(handler)
}

// WriteJSON is the single way a handler writes a JSON body.
func WriteJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v) // the client has gone if this fails; nothing to do
}

// WriteError writes a JSON error envelope. Never leak internal detail here.
func WriteError(w http.ResponseWriter, status int, code, message string) {
	WriteJSON(w, status, map[string]any{"error": map[string]string{"code": code, "message": message}})
}

func requestLog(logger *slog.Logger, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		sw := &middleware.StatusWriter{ResponseWriter: w, Status: http.StatusOK}
		next.ServeHTTP(sw, r)
		logger.Info("request",
			"method", r.Method, "path", r.URL.Path, "status", sw.Status,
			"duration_ms", time.Since(start).Milliseconds(),
			"request_id", middleware.RequestIDFrom(r.Context()))
	})
}
