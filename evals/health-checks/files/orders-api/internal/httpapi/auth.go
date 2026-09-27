package httpapi

import (
	"context"
	"errors"
	"net/http"
	"strings"
)

// publicPaths skip authentication. Everything else needs a bearer token.
var publicPaths = map[string]bool{
	"/health": true,
}

type ctxKey struct{}

func requireAuth(verify func(string) (string, error), next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if publicPaths[r.URL.Path] {
			next.ServeHTTP(w, r)
			return
		}
		tok, ok := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
		if !ok || tok == "" {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		sub, err := verify(tok)
		if err != nil {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), ctxKey{}, sub)))
	})
}

func subject(r *http.Request) string {
	s, _ := r.Context().Value(ctxKey{}).(string)
	return s
}

// jwksVerifier is a placeholder until the JWKS client lands (ORD-198);
// it rejects every token when no JWKS URL is configured.
func jwksVerifier(url string) func(string) (string, error) {
	return func(string) (string, error) {
		if url == "" {
			return "", errors.New("auth: no JWKS configured")
		}
		return "", errors.New("auth: JWKS verification not implemented")
	}
}
