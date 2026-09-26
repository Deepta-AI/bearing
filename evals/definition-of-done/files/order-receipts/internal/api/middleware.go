package api

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"log/slog"
	"net/http"
	"time"
)

type ctxKey int

const requestIDKey ctxKey = 0

// RequestID reads X-Request-Id or makes one, puts it on the context and
// the response, and logs every request with it.
func RequestID(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id := r.Header.Get("X-Request-Id")
		if id == "" {
			b := make([]byte, 8)
			_, _ = rand.Read(b)
			id = hex.EncodeToString(b)
		}
		w.Header().Set("X-Request-Id", id)
		ctx := context.WithValue(r.Context(), requestIDKey, id)
		start := time.Now()
		next.ServeHTTP(w, r.WithContext(ctx))
		slog.InfoContext(ctx, "request", "request_id", id, "method", r.Method, "path", r.URL.Path, "ms", time.Since(start).Milliseconds())
	})
}

// RequestIDFrom returns the request id on the context, or "".
func RequestIDFrom(ctx context.Context) string {
	id, _ := ctx.Value(requestIDKey).(string)
	return id
}
