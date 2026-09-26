package httpapi

import (
	"context"
	"net/http"
	"strings"
)

type partnerKey struct{}

// requireKey resolves the bearer API key to a partner id.
func requireKey(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		key := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
		partnerID, ok := lookupKey(key)
		if !ok {
			http.Error(w, "unauthorised", http.StatusUnauthorized)
			return
		}
		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), partnerKey{}, partnerID)))
	})
}

func lookupKey(key string) (string, bool) { return "", key != "" }

func issueToken(w http.ResponseWriter, r *http.Request)   { w.WriteHeader(http.StatusOK) }
func listCatalog(w http.ResponseWriter, r *http.Request)  { w.WriteHeader(http.StatusOK) }
func getOrder(w http.ResponseWriter, r *http.Request)     { w.WriteHeader(http.StatusOK) }
func createOrder(w http.ResponseWriter, r *http.Request)  { w.WriteHeader(http.StatusCreated) }
func exportReport(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusAccepted) }
