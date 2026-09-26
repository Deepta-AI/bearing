package middleware

import (
	"log/slog"
	"net/http"
	"runtime/debug"
)

// Recover turns a panic in a handler into a 500 with the standard error
// envelope and one error log line carrying the request id and the stack, so
// a bug in one request never takes the process down.
func Recover(logger *slog.Logger, writeError func(w http.ResponseWriter, status int, code, message string)) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			defer func() {
				if rec := recover(); rec != nil {
					logger.ErrorContext(r.Context(), "panic",
						"err", rec,
						"path", r.URL.Path,
						"request_id", RequestIDFrom(r.Context()),
						"stack", string(debug.Stack()))
					writeError(w, http.StatusInternalServerError, "internal", "internal error")
				}
			}()
			next.ServeHTTP(w, r)
		})
	}
}
