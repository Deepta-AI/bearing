// Package httpapi wires the HTTP routes of orders-api.
package httpapi

import (
	"database/sql"
	"log/slog"
	"net/http"

	"example.com/orders-api/internal/orders"
)

type Deps struct {
	Log     *slog.Logger
	DB      *sql.DB
	Orders  *orders.Service
	JWKSURL string
	// Verify checks a bearer token; nil means the JWKS verifier.
	Verify func(token string) (subject string, err error)
}

func NewRouter(d Deps) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", health(d.DB))
	mux.HandleFunc("POST /orders", createOrder(d))
	mux.HandleFunc("GET /orders/{id}", getOrder(d))

	verify := d.Verify
	if verify == nil {
		verify = jwksVerifier(d.JWKSURL)
	}
	return requestLog(d.Log, requireAuth(verify, mux))
}
