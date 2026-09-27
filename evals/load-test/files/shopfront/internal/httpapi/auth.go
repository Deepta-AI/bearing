package httpapi

import "net/http"

// RequireKey rejects a request whose X-Api-Key is not one of keys.
func RequireKey(keys []string, next http.Handler) http.Handler {
	allowed := map[string]bool{}
	for _, k := range keys {
		if k != "" {
			allowed[k] = true
		}
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !allowed[r.Header.Get("X-Api-Key")] {
			http.Error(w, "unknown api key", http.StatusUnauthorized)
			return
		}
		next.ServeHTTP(w, r)
	})
}
