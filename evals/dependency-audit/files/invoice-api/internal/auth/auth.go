// Package auth checks the bearer token on every API request.
package auth

import (
	"context"
	"net/http"
	"strings"
	"time"

	"mods.example.com/jwtkit"
)

type ctxKey struct{}

// Middleware rejects a request without a valid bearer token and puts the
// token's claims on the request context.
func Middleware(key []byte, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw, ok := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
		if !ok {
			http.Error(w, "missing token", http.StatusUnauthorized)
			return
		}
		claims, err := jwtkit.Parse(raw, key, jwtkit.ParseOptions{Leeway: 30 * time.Second})
		if err != nil {
			http.Error(w, "invalid token", http.StatusUnauthorized)
			return
		}
		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), ctxKey{}, claims)))
	})
}

// RequireRole lets the request through only when the token's role claim
// matches.
func RequireRole(role string, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		claims, _ := r.Context().Value(ctxKey{}).(jwtkit.Claims)
		if claims["role"] != role {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
		next.ServeHTTP(w, r)
	})
}
