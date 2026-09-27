// Package httpapi registers every route the service serves.
package httpapi

import (
	"expvar"
	"net/http"
	"strconv"

	"example.com/shopfront/internal/catalog"
	"example.com/shopfront/internal/orders"
)

type Config struct {
	APIKeys []string
	RPS     int
	Catalog *catalog.Catalog
	Orders  *orders.Handler
}

// NewRouter returns the service's handler. Routes:
//
//	GET  /healthz          no key
//	GET  /debug/vars       no key (expvar: memstats, cmdline); ingress blocks it in production
//	GET  /v1/search?q=&page=
//	POST /v1/orders
//	GET  /v1/orders/{id}
func NewRouter(c Config) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.Write([]byte("ok"))
	})
	mux.Handle("GET /debug/vars", expvar.Handler())

	v1 := http.NewServeMux()
	v1.HandleFunc("GET /v1/search", func(w http.ResponseWriter, r *http.Request) {
		page, _ := strconv.Atoi(r.URL.Query().Get("page"))
		body := c.Catalog.SearchJSON(r.URL.Query().Get("q"), page)
		w.Header().Set("Content-Type", "application/json")
		w.Write(body)
	})
	v1.HandleFunc("POST /v1/orders", c.Orders.Create)
	v1.HandleFunc("GET /v1/orders/{id}", c.Orders.Get)

	limited := RequireKey(c.APIKeys, NewLimiter(c.RPS).Middleware(v1))
	mux.Handle("/v1/", limited)
	return mux
}
