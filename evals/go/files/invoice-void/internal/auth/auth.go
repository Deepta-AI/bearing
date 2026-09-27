// Package auth resolves the X-API-Key header to a merchant account.
package auth

import (
	"context"
	"errors"
	"net/http"
)

// ErrUnknownKey is returned by a KeyLookup when no account has the key.
var ErrUnknownKey = errors.New("unknown api key")

// KeyLookup finds the account that owns an API key.
type KeyLookup interface {
	AccountForKey(ctx context.Context, key string) (int64, error)
}

type ctxKey struct{}

// WithAccount returns a copy of ctx carrying the caller's account id.
func WithAccount(ctx context.Context, accountID int64) context.Context {
	return context.WithValue(ctx, ctxKey{}, accountID)
}

// AccountID returns the caller's account id set by Middleware.
func AccountID(ctx context.Context) (int64, bool) {
	id, ok := ctx.Value(ctxKey{}).(int64)
	return id, ok
}

// Middleware rejects requests without a known key and puts the account id
// on the request context. onError writes the 401 or 500 response.
func Middleware(keys KeyLookup, onError func(w http.ResponseWriter, r *http.Request, err error)) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			key := r.Header.Get("X-API-Key")
			if key == "" {
				onError(w, r, ErrUnknownKey)
				return
			}
			id, err := keys.AccountForKey(r.Context(), key)
			if err != nil {
				onError(w, r, err)
				return
			}
			next.ServeHTTP(w, r.WithContext(WithAccount(r.Context(), id)))
		})
	}
}
