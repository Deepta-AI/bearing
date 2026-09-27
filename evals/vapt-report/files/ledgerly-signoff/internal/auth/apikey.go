// Package auth resolves API keys to tenants and handles dashboard login.
package auth

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"log"
	"net/http"
	"strings"
)

// Keys maps the SHA-256 hex of an API key to its tenant id.
type Keys map[string]string

// HashKey returns the stored form of an API key.
func HashKey(key string) string {
	h := sha256.Sum256([]byte(key))
	return hex.EncodeToString(h[:])
}

type tenantKey struct{}

// RequireAuth rejects requests without a known bearer API key and puts the
// tenant id on the context.
func (k Keys) RequireAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		tok, ok := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
		tenant, known := k[HashKey(tok)]
		if !ok || !known {
			log.Printf("auth: rejected key %q from %s", tok, r.RemoteAddr)
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), tenantKey{}, tenant)))
	})
}

// Tenant returns the tenant RequireAuth put on the context.
func Tenant(ctx context.Context) string {
	t, _ := ctx.Value(tenantKey{}).(string)
	return t
}

// WithTenant returns ctx carrying tenant (for tests).
func WithTenant(ctx context.Context, tenant string) context.Context {
	return context.WithValue(ctx, tenantKey{}, tenant)
}
