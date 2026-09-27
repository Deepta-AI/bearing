// Package api is the HTTP API.
package api

import (
	"log/slog"
	"net/http"
	"time"
)

// AccessLog writes one line per request.
func AccessLog(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		slog.Info("http",
			"method", r.Method,
			"url", r.URL.String(),
			"ip", r.RemoteAddr,
			"ms", time.Since(start).Milliseconds())
	})
}
