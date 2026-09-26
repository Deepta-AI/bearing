package orders

import (
	"log"
	"net/http"
)

// RequireAPIKey rejects every request without the shared key, except the
// health check the load balancer calls.
func RequireAPIKey(key string, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/healthz" {
			next.ServeHTTP(w, r)
			return
		}
		got := r.Header.Get("X-Api-Key")
		if key == "" || got != key {
			log.Printf("rejected request from %s: bad api key %q", r.RemoteAddr, got)
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		next.ServeHTTP(w, r)
	})
}
