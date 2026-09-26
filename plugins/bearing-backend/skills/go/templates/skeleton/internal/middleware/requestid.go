// Package middleware holds the HTTP middleware every service on this standard
// runs: request id, panic recovery and request metrics. Each is a plain
// func(http.Handler) http.Handler so the chain in httpapi reads top to bottom.
package middleware

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"net/http"
)

// HeaderRequestID is the header a caller or gateway uses to carry a request id.
const HeaderRequestID = "X-Request-Id"

type ctxKey struct{}

// RequestID accepts an incoming X-Request-Id or mints one, stores it on the
// context and echoes it on the response so a client can quote it in a report.
func RequestID(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id := r.Header.Get(HeaderRequestID)
		if id == "" || len(id) > 128 {
			id = newID()
		}
		w.Header().Set(HeaderRequestID, id)
		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), ctxKey{}, id)))
	})
}

// RequestIDFrom returns the request id bound to ctx, or "" outside a request.
func RequestIDFrom(ctx context.Context) string {
	id, _ := ctx.Value(ctxKey{}).(string)
	return id
}

func newID() string {
	var b [16]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "00000000000000000000000000000000" // rand failing means the process is in trouble anyway
	}
	return hex.EncodeToString(b[:])
}
